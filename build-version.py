#!/usr/bin/env python3
import os
import re
import subprocess
import hashlib
import sys
import argparse
import pathlib

def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description='Compile ASM file and auto-increment version if binary changes')
    parser.add_argument('source', help='Source ASM file path')
    parser.add_argument('output', help='Output binary file path')
    parser.add_argument('--symbols', help='Output symbols file path (optional)', default=None)
    return parser.parse_args()

def compile_asm(source_path, output_path, symbols_path=None):
    """Compile the ASM file"""
    cmd = ["customasm", source_path, "-f", "binary", "-o", output_path]
    
    if symbols_path:
        cmd.extend(["--", "-f", "symbols", "-o", symbols_path])
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode != 0:
        print(f"Compilation error: {result.stderr}")
        sys.exit(1)
    
    return True

def get_file_hash(file_path):
    """Calculate SHA-256 hash of a file"""
    if not os.path.exists(file_path):
        return None
    
    hash_obj = hashlib.sha256()
    with open(file_path, 'rb') as f:
        hash_obj.update(f.read())
    return hash_obj.hexdigest()

def read_last_hash(hash_file_path):
    """Read the stored hash of the last compiled binary"""
    if not os.path.exists(hash_file_path):
        return None
    
    with open(hash_file_path, 'r') as f:
        return f.read().strip()

def save_current_hash(hash_value, hash_file_path):
    """Save the current binary hash to a file"""
    with open(hash_file_path, 'w') as f:
        f.write(hash_value)

def get_version_constant_name(source_path):
    """Generate the expected version constant name based on the file name"""
    # Extract just the filename without extension or directory
    filename = os.path.basename(source_path)
    base_name = os.path.splitext(filename)[0].upper()
    return f"{base_name}_VERSION"

def increment_version(source_path, constant_name):
    """Increment the build number in the ASM file"""
    if not os.path.exists(source_path):
        print(f"Error: {source_path} not found")
        return False
    
    with open(source_path, 'r') as f:
        content = f.read()
    
    # Look for the version string pattern for this constant
    version_pattern = fr'(#const {constant_name} = "v\d+\.\d+\.)(\d+)(")'
    match = re.search(version_pattern, content)
    
    if not match:
        print(f"Version constant '{constant_name}' not found in {source_path}")
        return False
    
    # Extract the current version parts
    prefix = match.group(1)
    build_num = int(match.group(2))
    suffix = match.group(3)
    
    # Increment the build number
    new_build_num = build_num + 1
    
    # Replace the version string in the content
    new_content = re.sub(
        version_pattern,
        f'{prefix}{new_build_num}{suffix}',
        content
    )
    
    # Write the updated content back to the file
    with open(source_path, 'w') as f:
        f.write(new_content)
    
    version_prefix = prefix.split('"v')[1]
    current_version = f"v{version_prefix}{build_num}"
    new_version = f"v{version_prefix}{new_build_num}"
    print(f"Version incremented from {current_version} to {new_version}")
    return True

def main():
    # Parse command line arguments
    args = parse_arguments()
    
    # Determine hash file path (same as output but with .hash extension)
    output_path = pathlib.Path(args.output)
    hash_file_path = f"{output_path}.hash"
    
    # Get the version constant name based on source file name
    constant_name = get_version_constant_name(args.source)
    
    # Compile the ASM file
    compile_asm(args.source, args.output, args.symbols)
    
    # Get the hash of the newly compiled binary
    current_hash = get_file_hash(args.output)
    if current_hash is None:
        print(f"Error: Could not calculate hash for {args.output}")
        return
    
    # Get the hash of the previous binary
    last_hash = read_last_hash(hash_file_path)
    
    # If the binary has changed or no previous hash exists
    if current_hash != last_hash:
        print("Binary has changed. Incrementing version...")
        if increment_version(args.source, constant_name):
            # Recompile with the new version
            compile_asm(args.source, args.output, args.symbols)
            
            # Save the hash of the NEWLY compiled binary (after version change)
            new_hash = get_file_hash(args.output)
            save_current_hash(new_hash, hash_file_path)
            
            print("Version incremented and code recompiled successfully")
        else:
            print("Failed to increment version")
    else:
        print("No change in binary output. Version not incremented.")
        # Still save the hash to ensure the file exists
        save_current_hash(current_hash, hash_file_path)

if __name__ == "__main__":
    main()