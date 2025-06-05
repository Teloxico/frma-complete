import os

def collect_files_content(parent_dir='.', output_file='collected_content.txt'):
    """
    Collects the names (as headings) and content of all files within a 
    parent directory and its subdirectories, saving the output to a file.

    Args:
        parent_dir (str): The path to the parent directory to scan. 
                          Defaults to the current directory.
        output_file (str): The name of the file to save the collected content.
                           Defaults to 'collected_content.txt'.
    """
    collected_data = []
    
    # Ensure the parent directory exists
    if not os.path.isdir(parent_dir):
        print(f"Error: Directory '{parent_dir}' not found.")
        return

    print(f"Scanning directory: {os.path.abspath(parent_dir)}")
    
    for root, _, files in os.walk(parent_dir):
        for filename in files:
            file_path = os.path.join(root, filename)
            relative_path = os.path.relpath(file_path, parent_dir)
            
            # Skip the output file itself if it's in the scanned directory
            if os.path.abspath(file_path) == os.path.abspath(os.path.join(parent_dir, output_file)):
                continue

            collected_data.append(f"--- File: {relative_path} ---")
            try:
                # Try reading with utf-8, fallback to latin-1 for wider compatibility
                # Add more encodings or binary handling if needed
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                collected_data.append(content)
            except UnicodeDecodeError:
                try:
                    with open(file_path, 'r', encoding='latin-1') as f:
                        content = f.read()
                    collected_data.append(content)
                    collected_data.append("\n[Note: Read with latin-1 encoding due to UTF-8 decode error]")
                except Exception as e:
                    collected_data.append(f"[Error reading file: {e}]")
            except Exception as e:
                collected_data.append(f"[Error reading file: {e}]")
            collected_data.append("-" * (len(relative_path) + 14)) # Separator line
            collected_data.append("\n") # Add a newline for spacing

    # Write the collected data to the output file
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write("\n".join(collected_data))
        print(f"Successfully collected content into '{output_file}'")
    except Exception as e:
        print(f"Error writing to output file '{output_file}': {e}")

if __name__ == "__main__":
    # You can change '.' to a specific directory path if needed
    target_directory = '.' 
    output_filename = 'collected_project_content.txt'
    collect_files_content(parent_dir=target_directory, output_file=output_filename)