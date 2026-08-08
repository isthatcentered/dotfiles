#!/bin/bash
# Filter Plenary test output to show only failures with error messages
# Exit 0 if all pass, exit 1 if any failures

current_file=""
file_printed=0
in_error_block=0
total_tests=0
total_failures=0
files_with_failures=0

while IFS= read -r line; do
  # Strip ANSI color codes for matching
  stripped=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g')

  # Track current file
  if [[ "$stripped" =~ ^Testing:.*$ ]]; then
    current_file="$stripped"
    file_printed=0
    in_error_block=0
    continue
  fi

  # Count successes
  if [[ "$stripped" =~ ^Success.*\|\| ]]; then
    ((total_tests++))
    in_error_block=0
    continue
  fi

  # Detect failure
  if [[ "$stripped" =~ ^Fail.*\|\| ]]; then
    ((total_tests++))
    ((total_failures++))
    in_error_block=1

    # Print file header once per file with failures
    if [[ $file_printed -eq 0 ]]; then
      ((files_with_failures++))
      echo ""
      echo "$current_file"
      file_printed=1
    fi

    # Print the failure line (with colors preserved)
    echo "  $line"
    continue
  fi

  # Capture error message lines (indented content after a failure)
  if [[ $in_error_block -eq 1 ]]; then
    # Stop on separator or summary lines
    if [[ "$stripped" =~ ^={10,}$ ]] || [[ "$stripped" =~ ^Success: ]] || [[ "$stripped" =~ ^Failed\ : ]] || [[ "$stripped" =~ ^Errors\ : ]]; then
      in_error_block=0
      continue
    fi
    # Print error details (indented)
    if [[ -n "$stripped" ]]; then
      echo "    $line"
    fi
  fi
done

# Print summary
echo ""
if [[ $total_failures -eq 0 ]]; then
  echo "✓ All tests passed ($total_tests tests)"
  exit 0
else
  echo "✗ $total_failures failed, $((total_tests - total_failures)) passed ($files_with_failures file(s) with failures)"
  exit 1
fi
