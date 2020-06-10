function prompt_rm_dir() {
  for dir in $@; do 
    if [ -d $dir ]; then
      echo "WARNING: $dir already exists... should I delete it?"
      echo "enter: y/n"
      read del_dir
      if [ "$del_dir" == "y" ]; then
        rm -rf $dir
      fi
    fi
  done
}