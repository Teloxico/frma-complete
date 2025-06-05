import os
import torch
from fastapi import FastAPI, HTTPException, Request, Security
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from transformers import AutoTokenizer, AutoModelForCausalLM, BitsAndBytesConfig
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
import argparse
import logging
import gc
import json
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger("medical_llama_v2_server")

HARDCODED_MODEL_ID = "ruslanmv/Medical-Llama3-v2"

CHAT_SYSTEM_PROMPT = """You are a knowledgeable Medical AI Assistant.
USER PROFILE CONTEXT (if provided): Consider the user's age, gender, conditions, and allergies for more personalized and relevant answers. Do not explicitly restate the profile unless asked. Only reply to Question asked.
TASK: Provide helpful and informative answers to general medical queries in a clear and understanding way. If you don't know the answer or if it's a serious medical issue, advise seeking professional help from a doctor.
4. In case there are specialised medical terms, explain them in simple english(eg: . Pneumoperitoneum)
5. Do **NOT** generate quizzes, exam questions, or multiple-choice answers.
6. Do **NOT** ask the user to choose between A/B/C/D."""

EMERGENCY_SYSTEM_PROMPT = """You are an Emergency First Aid Advisor.
USER PROFILE CONTEXT (if provided): Consider the user's age, known conditions, and allergies when providing steps, but prioritize immediate life-saving actions.
TASK: Provide immediate, actionable, step-by-step first aid instructions for a layperson based STRICTLY on the situation and symptoms provided in the user prompt.
PRIORITY 1: If the situation sounds potentially life-threatening (e.g., stroke symptoms, unconsciousness, severe bleeding, difficulty breathing), your FIRST step MUST be '1. Call emergency services (like 911, 112, etc.) immediately!'.
Then, list ONLY simple, practical steps the person can take WHILE WAITING for professional help. Number each step (1., 2., 3., ...). Use simple language. Be concise and direct. ENSURE specific maneuvers are recommended when appropriate (eg: Heimlich for choking).
DO NOT explain medical conditions. DO NOT add conversational filler. Just provide the comprehensive numbered steps.
5. Do **NOT** generate quizzes, exam questions, or multiple-choice answers.
6. Do **NOT** ask the user to choose between A/B/C/D."""

class UserProfile(BaseModel):
    age: Optional[int] = None
    gender: Optional[str] = None
    conditions: Optional[List[str]] = None 
    allergies: Optional[List[str]] = None
    medications: Optional[List[str]] = None
    name: Optional[str] = None
    weight_kg: Optional[float] = None
    height_cm: Optional[float] = None
    blood_type: Optional[str] = None

class ChatMessage(BaseModel):
    role: str = Field(..., description="Role: 'user' or 'assistant'")
    content: str = Field(..., description="Message content")

class ChatRequest(BaseModel):
    prompt: str = Field(..., description="The current user prompt for the chat")
    history: List[ChatMessage] = Field(default=[], description="List of previous messages")
    user_profile: Optional[UserProfile] = Field(default=None, description="Optional user profile data") # Key matches client
    max_new_tokens: Optional[int] = 512
    temperature: Optional[float] = 0.7
    top_p: Optional[float] = 0.9

class EmergencyAssessmentRequest(BaseModel):
    # Changed to accept a single prompt matching ApiService
    prompt: str = Field(..., description="Combined situation summary and assessment details")
    user_profile: Optional[UserProfile] = Field(default=None, description="Optional user profile data")
    # Optional generation parameters
    max_new_tokens: Optional[int] = 768 
    temperature: Optional[float] = 0.3 
    top_p: Optional[float] = 0.7

class ApiResponse(BaseModel):
    answer: str = Field(..., description="The generated response from the model")

app = FastAPI(
    title="Medical AI API with Profile Context",
    version="2.4",
    description=f"Provides endpoints for medical chat and emergency assessment using {HARDCODED_MODEL_ID}, with optional profile context."
)

# --- Security/CORS ---
allowed_origins = [
    "http://localhost",
    "http://localhost:8080",
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

model = None
tokenizer = None
device = None
model_id_loaded = None

def load_model_and_tokenizer(precision: str, cache_dir: Optional[str]):
    global model, tokenizer, device, model_id_loaded
    model_id = HARDCODED_MODEL_ID
    if model is not None and model_id_loaded == model_id:
        logger.info(f"Model '{model_id}' is already loaded.")
        return

    logger.info(f"Starting model loading: {model_id} ({precision})")
    if cache_dir: logger.info(f"Cache directory: {cache_dir}")
    if model is not None:
        logger.warning(f"Clearing previous model: {model_id_loaded}")
        del model; del tokenizer; model, tokenizer, model_id_loaded = None, None, None
        gc.collect();
        if torch.cuda.is_available(): torch.cuda.empty_cache()
    if torch.cuda.is_available():
        device = torch.device("cuda")
        logger.info("Using GPU.")
    else:
        device = torch.device("cpu")
        logger.info("Using CPU.")
        precision = "16-bit" if precision == "4-bit" else precision

    bnb_config = None
    model_kwargs = {"cache_dir": cache_dir, "trust_remote_code": True}

    if precision == "4-bit" and device.type == 'cuda':
        logger.info("Configuring 4-bit quantization.")
        bnb_config = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_compute_dtype=torch.float16
        )
        model_kwargs["quantization_config"] = bnb_config
    elif precision == "16-bit":
        logger.info("Using 16-bit precision (float16).")
        model_kwargs["torch_dtype"] = torch.float16
    else: # 32-bit
        logger.info("Using 32-bit precision (float32).")
    try:
        logger.info("Loading tokenizer...");
        tokenizer = AutoTokenizer.from_pretrained(model_id, cache_dir=cache_dir, trust_remote_code=True)
        if tokenizer.pad_token is None or tokenizer.pad_token_id == tokenizer.eos_token_id:
            tokenizer.pad_token = tokenizer.eos_token
        if tokenizer.pad_token_id is None: 
             tokenizer.pad_token_id = tokenizer.eos_token_id
        logger.info("Tokenizer loaded.")
    except Exception as e:
        logger.error(f"Tokenizer Loading Error: {e}", exc_info=True)
        raise 
    try:
        logger.info("Loading model...");
        model = AutoModelForCausalLM.from_pretrained(model_id, **model_kwargs)
        model.eval()
        try:
             current_device = next(model.parameters()).device
             logger.info(f"Model parameter check: Device is {current_device}")
             if current_device != device and not model_kwargs.get("quantization_config"):
                 logger.info(f"Moving model explicitly to target device: {device}")
                 model.to(device)
             elif model_kwargs.get("quantization_config") and current_device.type != 'cuda':
                 logger.warning(f"Quantized model loaded but not on CUDA ({current_device}). Quantization may not be effective.")
             else:
                 logger.info(f"Model placement seems correct. Target: {device}, Actual: {current_device}")
        except Exception as placement_e:
            logger.warning(f"Could not verify final model device placement: {placement_e}")


        model_id_loaded = model_id
        logger.info(f"Model '{model_id}' ({precision}) loaded successfully.")
    except Exception as e:
        logger.error(f"Model Loading Error: {e}", exc_info=True)
        del tokenizer; tokenizer=None; model=None; model_id_loaded=None
        gc.collect();
        if torch.cuda.is_available(): torch.cuda.empty_cache()
        raise


@app.on_event("startup")
async def startup_event():
    logger.info("Application startup...")
    app.state.cli_args_parsed = args # Make sure 'args' is accessible here or passed differently
    if args.preload:
        logger.info(f"Preloading model '{HARDCODED_MODEL_ID}'...")
        try:
            load_model_and_tokenizer(args.precision, args.cache_dir)
        except Exception as e:
            logger.error(f"Model preloading failed: {e}", exc_info=True)
            # Decide if app should exit or continue without preloaded model
            # raise RuntimeError("Failed to preload model, exiting.") from e
    else:
        logger.info("Model preloading disabled. Model will load on first request.")

# --- Health Check ---
@app.get("/health")
async def health_check():
    # More informative health check
    model_status = "not loaded"
    active_model_id = "None"
    if model is not None and tokenizer is not None:
         model_status = "loaded"
         active_model_id = model_id_loaded
    # Could add a quick inference test here if needed, but keep it fast
    return JSONResponse(content={
        "status": "healthy",
        "model_status": model_status,
        "model_id": active_model_id
    })

# --- Reusable Generation Function (Handles Profile Context) ---
def _generate_response(
    system_prompt_base: str,
    user_content: str,
    history_list: List[Dict[str, str]],
    gen_params: Dict[str, Any],
    profile_data: Optional[Dict[str, Any]] # Profile data as dict
):
    global model, tokenizer, device
    if model is None or tokenizer is None:
        logger.warning("Model lazy load trigger...")
        cli_args = app.state.cli_args_parsed # Access args from app state
        try:
            load_model_and_tokenizer(cli_args.precision, cli_args.cache_dir)
        except Exception as e:
            # Use 503 Service Unavailable for model loading issues
            raise HTTPException(status_code=503, detail=f"Model service temporarily unavailable: {e}")

    try:
        system_prompt = system_prompt_base 
        profile_context_added = False
        if profile_data:
            profile_parts = []
            # Add non-empty/non-null profile fields clearly
            if profile_data.get('age'): profile_parts.append(f"- Age: {profile_data['age']}")
            if profile_data.get('gender'): profile_parts.append(f"- Gender: {profile_data['gender']}")
            if profile_data.get('conditions'): profile_parts.append(f"- Known Conditions: {', '.join(profile_data['conditions'])}")
            if profile_data.get('allergies'): profile_parts.append(f"- Known Allergies: {', '.join(profile_data['allergies'])}")
            if profile_data.get('medications'): profile_parts.append(f"- Current Medications: {', '.join(profile_data['medications'])}")
            # Add weight/height/blood_type if present and needed
            # if profile_data.get('weight_kg'): profile_parts.append(f"- Weight: {profile_data['weight_kg']} kg")
            # if profile_data.get('height_cm'): profile_parts.append(f"- Height: {profile_data['height_cm']} cm")
            # if profile_data.get('blood_type'): profile_parts.append(f"- Blood Type: {profile_data['blood_type']}")

            if profile_parts:
                 profile_str = "User Profile:\n" + "\n".join(profile_parts)
                 # Prepend profile context to the system prompt
                 system_prompt = profile_str.strip() + "\n\n" + system_prompt_base
                 profile_context_added = True

        # logger.info(f"Using profile context: {profile_context_added}")
        # Uncomment below for debugging the exact prompt being sent
        # logger.debug(f"Effective System Prompt:\n----\n{system_prompt}\n----")
        # --- End Profile Incorporation ---

        # 1. Construct messages list for the chat template
        messages = [{"role": "system", "content": system_prompt}] + history_list + [{"role": "user", "content": user_content}]

        # 2. Apply the chat template
        # Important: Ensure add_generation_prompt=True for inference
        prompt_formatted = tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True
        )
        # logger.debug(f"Formatted Prompt for Model:\n----\n{prompt_formatted}\n----")


        # 3. Tokenize the formatted prompt
        # No padding needed for single sequence generation usually
        inputs = tokenizer(prompt_formatted, return_tensors="pt", truncation=True, padding=False, max_length=4096) # Increased context
        input_ids = inputs["input_ids"].to(device)
        attention_mask = inputs["attention_mask"].to(device) if "attention_mask" in inputs else torch.ones_like(input_ids).to(device)
        input_length = input_ids.shape[1] # Length of the input prompt tokens

        # 4. Prepare generation configuration
        generation_config = {
            "max_new_tokens": gen_params.get('max_new_tokens', 512),
            "eos_token_id": tokenizer.eos_token_id,
            "pad_token_id": tokenizer.pad_token_id, # Crucial for stopping criteria
            "use_cache": True, # Essential for faster generation
            # Add other params from request or defaults
            "temperature": gen_params.get('temperature', 0.7),
            "top_p": gen_params.get('top_p', 0.9),
            # "top_k": gen_params.get('top_k', 50), # Add if needed
            "do_sample": True, # Enable sampling based on temp/top_p
        }

        # Ensure do_sample is True if temp/top_p/top_k are set for sampling
        if generation_config["temperature"] <= 0.0 and generation_config["top_p"] >= 1.0:
             generation_config["do_sample"] = False # Use greedy search if temp=0, top_p=1
             # Remove sampling parameters if not doing sampling
             generation_config.pop("temperature", None)
             generation_config.pop("top_p", None)
             # generation_config.pop("top_k", None)


        logger.info(f"Generating response (max_new_tokens={generation_config['max_new_tokens']}, do_sample={generation_config['do_sample']})...")

        # 5. Generate response tokens
        with torch.no_grad():
            outputs = model.generate(
                input_ids=input_ids,
                attention_mask=attention_mask, # Pass attention mask
                **generation_config
            )
        logger.info("Generation complete.")

        # 6. Decode only the newly generated tokens
        newly_generated_token_ids = outputs[0][input_length:]
        assistant_response = tokenizer.decode(newly_generated_token_ids, skip_special_tokens=True).strip()

        # Uncomment for debugging raw output
        # logger.debug(f"Raw model output:\n----\n{assistant_response}\n----")

        # Optional: Add post-processing to clean up response if needed
        # assistant_response = assistant_response.replace("Assistant:", "").strip()

        return assistant_response

    except Exception as e:
        logger.error(f"Error during generation: {e}", exc_info=True)
        # Use 500 Internal Server Error for generation failures
        raise HTTPException(status_code=500, detail=f"Error generating response: {e}")


# --- Chat Endpoint ---
@app.post("/chat", response_model=ApiResponse)
async def chat(request: ChatRequest): # Unsecured for now
    # Log basic info, avoid logging sensitive prompt/profile details unless debugging
    profile_was_provided = request.user_profile is not None
    logger.info(f"/chat called. History: {len(request.history)} turns. Profile provided: {profile_was_provided}")

    # Prepare history list
    history_dict_list = [msg.model_dump() for msg in request.history] # Use model_dump

    # Prepare generation parameters
    gen_params = {
        "max_new_tokens": request.max_new_tokens,
        "temperature": request.temperature,
        "top_p": request.top_p
    }

    # Prepare profile dictionary (handle potential None)
    profile_dict = request.user_profile.model_dump(exclude_unset=True) if profile_was_provided else None

    # Call the reusable generation function
    answer = _generate_response(
        system_prompt_base=CHAT_SYSTEM_PROMPT,
        user_content=request.prompt,
        history_list=history_dict_list,
        gen_params=gen_params,
        profile_data=profile_dict
    )
    return ApiResponse(answer=answer)

# --- CORRECTED Emergency Assessment Endpoint ---
@app.post("/emergency_assessment", response_model=ApiResponse)
async def emergency_assessment(request: EmergencyAssessmentRequest): # Unsecured for now
    # Log basic info
    profile_was_provided = request.user_profile is not None
    logger.info(f"/emergency_assessment called. Profile provided: {profile_was_provided}")
    # Avoid logging the full prompt by default unless debugging
    # logger.debug(f"Emergency prompt received: {request.prompt}")

    # Prepare generation parameters
    gen_params = {
        "max_new_tokens": request.max_new_tokens,
        "temperature": request.temperature,
        "top_p": request.top_p
    }

    # Prepare profile dictionary
    profile_dict = request.user_profile.model_dump(exclude_unset=True) if profile_was_provided else None

    # Call the reusable generation function with the specific emergency prompt
    # The user_content is the full prompt received from the client
    answer = _generate_response(
        system_prompt_base=EMERGENCY_SYSTEM_PROMPT,
        user_content=request.prompt, # Use the prompt directly
        history_list=[], # No history for emergency assessment
        gen_params=gen_params,
        profile_data=profile_dict
    )
    return ApiResponse(answer=answer)


# --- Main Execution ---
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=f"Medical AI FastAPI Server (Model: {HARDCODED_MODEL_ID})")
    parser.add_argument("--host", type=str, default="0.0.0.0", help="Host IP to bind to (0.0.0.0 for all interfaces)")
    parser.add_argument("--port", type=int, default=8000, help="Port to listen on")
    parser.add_argument("--precision", type=str, choices=["4-bit", "16-bit", "32-bit"], default="4-bit", help="Model loading precision (4-bit requires CUDA and bitsandbytes)")
    parser.add_argument("--cache-dir", type=str, default=None, help="Hugging Face cache directory (optional)")
    parser.add_argument("--preload", action="store_true", help="Preload the model on startup")
    parser.add_argument("--workers", type=int, default=1, help="Number of Uvicorn workers (MUST be 1 for stateful models)", choices=[1])
    args = parser.parse_args()

    # Store args globally if needed by endpoints (e.g., via app.state)
    app.state.cli_args_parsed = args

    logger.info(f"Starting Uvicorn server on {args.host}:{args.port}")
    logger.info(f"Using Model: {HARDCODED_MODEL_ID}")
    logger.info(f"Precision: {args.precision}")
    if args.cache_dir: logger.info(f"Cache Directory: {args.cache_dir}")
    logger.info(f"Preload Model: {'Enabled' if args.preload else 'Disabled'}")
    logger.warning("CORS enabled for specified origins. Review for production deployment.")
    logger.warning("API endpoints are currently unsecured. Implement authentication/authorization for production.")

    # Run Uvicorn server
    uvicorn.run(
        app,
        host=args.host,
        port=args.port,
        workers=args.workers,
        log_config=None # Use root logger configuration
    )