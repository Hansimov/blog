import re
import sys
import os

from copy import deepcopy
from typing import Union


def get_all_filepaths_under_dir(
    workdir: str, exclude_patterns: list[str] = None
) -> list[str]:
    filepaths: list[str] = []
    for root, dirs, files in os.walk(workdir):
        for file in files:
            filepath = os.path.join(root, file)
            if exclude_patterns:
                if any(pattern in filepath for pattern in exclude_patterns):
                    continue
            filepaths.append(filepath)
    return filepaths


def get_filepath_by_name(
    all_filepaths: list[str], filename: str, ignore_case: bool = True
) -> Union[str, list[str]]:
    filename = filename.strip()
    filepaths = deepcopy(all_filepaths)
    if ignore_case:
        filename = filename.lower()
        filepaths = [fp.lower() for fp in filepaths]
    basenames = [os.path.basename(fp) for fp in filepaths]
    # case1: match full basename
    if filename in basenames:
        idx = basenames.index(filename)
        return all_filepaths[idx]
    # case2: match no-ext basename
    for idx, basename in enumerate(basenames):
        if os.path.splitext(basename)[0] == filename:
            return all_filepaths[idx]
    # case3: match by regex
    filename = filename.replace(".", r"\.").replace("*", ".*")
    pattern = re.compile(filename)
    res = []
    for idx, filepath in enumerate(filepaths):
        if pattern.search(filepath):
            res.append(all_filepaths[idx])
    if len(res) == 0:
        return None
    else:
        return res


def get_selected_paths(workdir: str, selected_files_arg: str) -> list[str]:
    selected_files = selected_files_arg.split(",")
    selected_paths = []
    all_filepaths = get_all_filepaths_under_dir(workdir)
    for filename in selected_files:
        filepath = get_filepath_by_name(all_filepaths, filename)
        if filepath:
            if isinstance(filepath, list):
                selected_paths.extend(filepath)
                for fp in filepath:
                    print(f"  + {fp}")
            else:
                selected_paths.append(filepath)
                print(f"  + {filepath}")
        else:
            print(f"  × {filename}")
    return selected_paths


def get_relative_paths(workdir: str) -> list[str]:
    relative_file = sys.argv[2]
    relative_path = os.path.join(workdir, relative_file)
    filepaths = [relative_path]
    print(f"  * {relative_path}")
    return filepaths


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
    workdir = sys.argv[1]
    selected_files_arg = sys.argv[3]
    print(f"> selected files:")
    if not selected_files_arg.strip():
        filepaths = get_relative_paths(workdir)
    else:
        filepaths = get_selected_paths(workdir, selected_files_arg)

    dump_contexts(filepaths)


if __name__ == "__main__":
    main()
