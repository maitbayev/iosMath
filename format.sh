set -euo pipefail

clang_format() {
  local dir=$1
  echo "Formatting $dir\n\n"
  for file in $(find $dir -name '*.h' -or -name '*.m' -or -name '*.mm'); do
    echo "Formatting $file"
    clang-format $file -i
  done
}

format() {
  local dir=$1
  echo "Formatting $dir"
  swift format --in-place --parallel -r $dir
}

lint() {
  local dir=$1
  echo "Linting $dir"
  swift format lint --strict --parallel -r $dir
}

format .
lint . 

