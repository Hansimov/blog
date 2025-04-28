import sys
import os


def get_file_path_by_name(
    workspace_folder: str,
    filename: str,
    ignore_case: bool = True,
    ignore_ext: bool = True,
) -> str:
    filename = filename.strip()
    for root, dirs, files in os.walk(workspace_folder):
        for file in files:
            if ignore_case:
                src = filename.lower()
                dst = file.lower()
            else:
                src = filename
                dst = file
            if ignore_ext:
                src = os.path.splitext(src)[0]
                dst = os.path.splitext(dst)[0]
            if src == dst:
                return os.path.join(root, file)
    return None


def get_selected_paths(workspace_folder: str, selected_files_arg: str) -> list[str]:
    selected_files = selected_files_arg.split(",")
    selected_paths = []
    for filename in selected_files:
        filepath = get_file_path_by_name(workspace_folder, filename)
        if filepath:
            selected_paths.append(filepath)
            print(f"  + {filepath}")
        else:
            print(f"  × {filename}")
    return selected_paths


def get_relative_paths(workspace_folder: str) -> list[str]:
    relative_file = sys.argv[2]
    relative_path = os.path.join(workspace_folder, relative_file)
    file_paths = [relative_path]
    print(f"  * {relative_path}")
    return file_paths


def dump_contexts(context_paths: list[str]) -> str:
    context_str = ""
    output_path = os.path.expanduser("~/scripts/copied.txt")
    for context_path in context_paths:
        try:
            with open(context_path, "r") as file:
                context_content = file.read()
        except Exception as e:
            print(f"× Error reading file: {e}")
            return
        context_str += f"here is `{context_path}`:\n```\n{context_content}\n```\n\n"

    print(f"> dump contexts to:")
    try:
        with open(output_path, "w") as output_file:
            output_file.write(context_str)
        print(f"  * {output_path}")
    except Exception as e:
        print(f"  × Error writing to file: {e}")


def main():
    workspace_folder = sys.argv[1]
    selected_files_arg = sys.argv[3]
    print(f"> select files:")
    if not selected_files_arg.strip():
        file_paths = get_relative_paths(workspace_folder)
    else:
        file_paths = get_selected_paths(workspace_folder, selected_files_arg)

    dump_contexts(file_paths)


if __name__ == "__main__":
    main()
