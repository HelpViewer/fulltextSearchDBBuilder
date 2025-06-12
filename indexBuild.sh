#!/bin/sh

date

echo "::group::Current user defined file list"
declare -A fileList
i_fileList=0
while IFS='|' read -r left _; do
  fileList["$left"]="$i_fileList"
  echo "$left => [$i_fileList]"
  ((i_fileList++))
done < "$1/files.lst"
echo "::endgroup::"

echo "::group::Directory $1 file index"
shopt -s globstar nullglob
files=("$1"**/*.{htm,html,md})

echo "Files found:"
for file in "${files[@]}"; do
  echo "$file"
done
echo "::endgroup::"

lenPar1=${#1}

declare -A freqs

for filename in "${files[@]}"; do
  echo "::group::File $filename processing ..."
  encoding=$(file -bi "$filename" | sed -n 's/.*charset=\(.*\)$/\1/p' | tr '[:upper:]' '[:lower:]')
  echo "  Detected encoding: $encoding"
  echo "::endgroup::"
  
  if [[ ! ( "$encoding" == "utf-8" || "$encoding" == "utf8" ) ]]; then
    echo "::group::File $filename encoding $encoding conversion ..."
    iconv -f "$encoding" -t utf-8 "$filename" > "${filename}.utf8"
    mv -f "${filename}.utf8" "${filename}"
    echo "Conversion to utf-8 done."
    echo "::endgroup::"
  fi
  
  echo "::group::File $filename source text processing ..."
  _fname=${filename:$lenPar1}
  
  if [[ ! -v fileList[$_fname] ]]; then
    echo "file name added $_fname to file list ... "
    fileList["$_fname"]="$i_fileList"
    echo "$_fname => [$i_fileList]"
    ((i_fileList++))
    echo "$_fname|" >> "$1/files.lst"
  fi
  
  _fname=${fileList[$_fname]}
  
  text=
  echo "reading ..."
  if [[ "$filename" =~ \.html?$ ]]; then
    text=$(sed '/<script/,/<\/script>/d; s/<[^>]*>//g' "$filename")
  fi
  
  if [[ "$filename" =~ \.md$ ]]; then
    text=$(< "$filename")
  fi
  
  echo "lowercase ..."
  text="${text,,}"
  echo "diacritics out ..."
  text=$(echo "$text" | iconv -f UTF-8 -t ASCII//TRANSLIT | sed 's/[^a-z0-9 ]//g')
  
  while read -r count word; do
    count_padded=$(printf "%06d" "$count")
    key="$word"
    value="${count_padded}:${_fname}"
  
    if [[ -n "${freqs[$key]}" ]]; then
      freqs[$key]+=" $value"
    else
      freqs[$key]="$value"
    fi
  done < <(echo "$text" | sed 's/[^a-zA-Z]/\n/g' | grep -E '.{3,}' | sort | uniq -c | sort -k1,1nr)
  echo "::endgroup::"
done

echo "::group::buffers ordering  ..."
date
orderedKeys=$(printf '%s\n' "${!freqs[@]}" | sort)
rm "$1/fts-keywords.lst"
rm "$1/fts-keywords-files.lst"

i_kwd=0
for key in $orderedKeys; do
  #echo "$key -> ${freqs[$key]}"
  sorted=$(echo "${freqs[$key]}" | tr ' ' '\n' | sort -r | tr '\n' ' ' | sed 's/ $//')
  sorted=$(echo "$sorted" | tr ' ' '\n' | cut -d':' -f2 | paste -sd';' -)
  freqs[$key]="$sorted"
  echo "$key" >> "$1/fts-keywords.lst"
  echo "$sorted" >> "$1/fts-keywords-files.lst"
  ((i_kwd++))
done
echo "::endgroup::"

echo "statistics:"
echo "Processed files: ${#files[@]}"
echo "Keywords:        ${i_kwd}"

echo "end ..."
date