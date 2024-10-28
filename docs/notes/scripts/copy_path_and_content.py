import sys
import os


def main():
    workspace_folder = sys.argv[1]
    relative_file = sys.argv[2]
    relative_path = os.path.join(workspace_folder, relative_file)

    try:
        with open(relative_path, "r") as file:
            file_content = file.read()
    except Exception as e:
        print(f"Error reading file: {e}")
        return

    formatted_string = f"here is `{relative_file}`:\n```\n{file_content}\n```\n\n"
    output_file_path = os.path.expanduser("~/scripts/copied.txt")
    try:
        with open(output_file_path, "w") as output_file:
            output_file.write(formatted_string)
        print(f"Content written to {output_file_path}.")
    except Exception as e:
        print(f"Error writing to file: {e}")


if __name__ == "__main__":
    main()
