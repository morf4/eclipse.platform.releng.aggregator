#!/usr/bin/env bash
# I am not sure what this is for?
for file in drops4/* 
do
  if [[ -d $file ]] 
  then
    echo "copying testConfigs.php to $file/"
    cp testConfigs.php $file/
  fi
done
