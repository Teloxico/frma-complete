# FRMA

## Overview

This project consists of two main parts:

1.  **Flutter Frontend:** A mobile application ("FRMA") built with Flutter. It provides users with features like a health chat interface, health metric tracking, medication reminders, appointment management, and emergency care guidance.
2.  **Python Backend:** A FastAPI server that hosts a large language model (specifically `ruslanmv/Medical-Llama3-v2`) fine-tuned for medical question answering and emergency first aid advice. It processes requests from the Flutter app, incorporating user profile context for more personalized responses.

The Flutter app communicates with the backend server via HTTP requests managed by the `ApiService`.

## Features

### Flutter Frontend (App)

* **Health Chat:** Interact with the AI assistant for general medical queries. Supports conversation history saving (optional). Includes profile context in requests.
* **Health Metrics:** View personal health data like BMI, weight, height, blood type, medical conditions, allergies, and medications stored in the user profile.
* **Medication Reminders:** Add and manage medication reminders. Reminders can be populated from the user's profile.
* **Appointments:** Schedule and track medical appointments. Data is stored locally.
* **Emergency Care:**
    * Provides a list of common emergencies.
    * Initiates an assessment flow for selected emergencies, asking relevant questions.
    * Sends assessment details to the backend for tailored first-aid instructions.
    * Quick access to call local emergency numbers (determined by location or default).
* **Profile Management:** Enter and edit personal details, health conditions, allergies, medications, and emergency contacts. Profile data can be password protected.
* **Settings:**
    * Configure API connection (Local Server URL or RunPod API Key/Endpoint ID).
    * Customize appearance (Theme Mode, Primary Color, Font Size).
    * Toggle notifications and sound effects.
    * Manage data privacy (save history, export data, clear data).

### Python Backend (Medical AI Server)

* **FastAPI Framework:** Provides a robust and efficient API structure.
* **Medical LLM:** Loads and serves the `ruslanmv/Medical-Llama3-v2` model using Hugging Face Transformers.
* **Quantization Support:** Optional 4-bit quantization using `bitsandbytes` for reduced memory footprint (requires CUDA). Also supports 16-bit and 32-bit precision.
* **Endpoints:**
    * `/chat`: Handles general medical questions, incorporating conversation history and user profile context.
    * `/emergency_assessment`: Processes detailed emergency situation prompts (including assessment answers and profile context) to generate first aid steps.
    * `/health`: Basic health check endpoint indicating server and model status.
* **Profile Context Integration:** System prompts are dynamically updated with relevant user profile data (age, gender, conditions, etc.) before generating responses.
* **CORS:** Configured for local development origins.

## System Requirements

### Frontend (Mobile App - Android/iOS)

* **Operating System:**
    * Android: API level 21 (Android 5.0 Lollipop) or later.
    * iOS: iOS 12.0 or later.
* **RAM:** 2GB (Minimum), 3GB+ (Recommended) for smooth performance.
* **Storage:** ~100-200MB free space (will vary based on cached data and dependencies).

### Backend (Local Server/Development Laptop)

These requirements depend heavily on the chosen model precision (`--precision` flag).

* **Minimum (for 4-bit quantization):**
    * **OS:** Linux (Recommended), macOS, Windows (with WSL2 recommended for CUDA).
    * **CPU:** Modern multi-core processor (e.g., Intel Core i5 / AMD Ryzen 5 or better).
    * **RAM:** **16 GB** (System Memory). More is better if running other applications.
    * **GPU:** NVIDIA GPU with CUDA support.
    * **VRAM:** **8 GB** (GPU Memory). This is sufficient for the 4-bit quantized Llama 3 8B model.
    * **Storage:** ~20-30 GB free space (for model download, dependencies, and virtual environment).
    * **Software:** Python 3.x, CUDA Toolkit (if using GPU), Pip.
* **Recommended (for 16-bit precision or smoother 4-bit operation):**
    * **RAM:** 32 GB+
    * **VRAM:** 16 GB+ (Required for 16-bit precision), 12GB+ recommended for comfortable 4-bit.
* **Note:** Running in 32-bit precision requires significantly more RAM and VRAM (~32GB+ VRAM). CPU-only inference is possible but will be extremely slow for a model of this size.

## Prerequisites

* **Flutter:** Flutter SDK installed (check Flutter documentation for setup).
* **Python:** Python 3.x installed.
* **CUDA (Optional):** If using 4-bit precision for the backend model on GPU, a CUDA-compatible NVIDIA GPU and the CUDA toolkit are required.
* **Dependencies:**
    * **Flutter:** Run `flutter pub get` in the Flutter project directory. Key dependencies include `provider`, `shared_preferences`, `http`, `flutter_local_notifications`, `geolocator`, `url_launcher`, etc.
    * **Python:** A `requirements.txt` file should ideally be created for the backend. Key dependencies include `fastapi`, `uvicorn`, `torch`, `transformers`, `bitsandbytes`, `pydantic`, `python-multipart`, `accelerate`.

## Setup Instructions

### 1. Backend Setup (Python Server)

1.  **Clone/Download:** Get the backend code (`server.py`).
2.  **Create Virtual Environment:**
    ```bash
    python -m venv venv
    source venv/bin/activate  # Linux/macOS
    # venv\Scripts\activate  # Windows
    ```
3.  **Install Dependencies:** It's recommended to have a `requirements.txt` file for the backend. If one exists, run:
    ```bash
    pip install -r requirements.txt
    ```
    If no `requirements.txt` is available, install the core dependencies manually (adjust `torch` installation for your specific CUDA version if applicable, see PyTorch website):
    ```bash
    pip install fastapi uvicorn torch transformers bitsandbytes pydantic python-multipart accelerate
    ```
4.  **(Optional) Download Model:** The model can be downloaded automatically on first run or pre-downloaded to a cache directory specified with `--cache-dir`.
5.  **Run the Server:** See the "Running the Application" section below.

### 2. Frontend Setup (Flutter App)

1.  **Clone/Download:** Get the Flutter project code (all Dart files organized into the standard Flutter structure: `lib/`, `lib/pages/`, `lib/providers/`, etc.).
2.  **Navigate to Project:** `cd <your_flutter_project_directory>`
3.  **Get Dependencies:**
    ```bash
    flutter pub get
    ```
4.  **Configure API:** Run the app once (see below) and navigate to `Settings` -> `API Configuration`.
    * **If using the local backend:** Select "Local Server", enter the URL where your `server.py` is running (e.g., `http://<your-local-ip>:8000` or `http://10.0.2.2:8000` if running Flutter on an Android emulator and the server on the host machine).
    * **If using RunPod:** Select "RunPod", enter your RunPod API Key and Endpoint ID.
5.  **Save & Test:** Save the API settings and use the "Test Connection" button.

## Running the Application

### 1. Backend Server

* Open your terminal, activate the virtual environment (`source venv/bin/activate` or `venv\Scripts\activate`).
* Run the server using uvicorn:
    ```bash
    # Example for 4-bit precision with preloading
    python server.py --host 0.0.0.0 --port 8000 --precision 4-bit --preload
    ```
* **Arguments:**
    * `--host`: IP address to bind to (`0.0.0.0` makes it accessible on your local network).
    * `--port`: Port number (default `8000`).
    * `--precision`: `4-bit`, `16-bit`, or `32-bit` (default `4-bit`). 4-bit requires CUDA.
    * `--cache-dir`: (Optional) Path to Hugging Face cache.
    * `--preload`: (Optional) Load the model on startup instead of the first request.
    * `--workers`: Must be 1 for stateful models.

### 2. Frontend App

* Connect a device or start an emulator/simulator.
* Navigate to the Flutter project directory in your terminal.
* Run the app:
    ```bash
    flutter run
    ```

## Configuration

* **API Mode:** Choose between connecting to a locally running `server.py` instance or a deployed RunPod endpoint via the app's Settings page.
* **Profile Password:** The first time you edit the profile, you'll be prompted to set a password to protect it. Subsequent edits will require this password.
* **Appearance:** Theme (Light/Dark/System), Primary Color, and Font Size can be adjusted in Settings.
* **Data:** Conversation history saving, data export, and data clearing options are available in Settings.

## Notes

* **Model:** The backend uses `ruslanmv/Medical-Llama3-v2`. Loading can take time and significant resources (RAM/VRAM), especially without quantization. See System Requirements.
* **Security:** The provided server code does not include authentication or authorization. It's suitable for local use but **must be secured** before any production deployment.
* **CORS:** The server allows requests from `http://localhost` and `http://localhost:8080`. Adjust `allowed_origins` in `server.py` if your Flutter app runs on a different origin during development (e.g., when testing on a physical device).
* **Location:** The app uses `geolocator` and `geocoding` for location services, primarily for emergency number determination and context. Location permissions are required.
* **Inference:** Inference currently only is fully supported in pc, using runpod, it is doable to get AI inference.
