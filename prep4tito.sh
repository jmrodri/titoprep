#!/bin/sh
function expandmacros ()
{
    local name=$1
    local toreplace=$2
    local replacment=$3
    local rc=`echo $1 | sed "s/$2/$3/g"`
    echo $rc
}

function filefromurl ()
{
    local url=$1
    local spliturl=(`echo $url | tr "/" "\n"`)
    local len=${#spliturl[@]}
    echo ${spliturl[$len-1]}
}

#TEST="true"
TEST=""

declare -a files
count=0
for file in *.spec
do
  if [ "$file" == "*.spec" ] ; then
      echo "no spec files found, skipping"
      break
  fi

  files[count]=$file
  ((count++))

  pkg=`basename $file .spec`
  name=`grep ^Name $file | awk '{print $2}'`
  version=`grep ^Version $file | awk '{print $2}'`
  sources=( `grep ^Source $file | awk '{print $2}'` )
  patches=( `grep ^Patch $file | awk '{print $2}'` )
  srclen=${#sources[@]}
  patchlen=${#patches[@]}

  echo "Processing $file"
  # special cases
  # - rubygems
  gemname=`grep "define gemname" $file | awk '{print $3}'`
  if [ "$gemname" != "" ] ; then
      name=$(expandmacros $name '%{gemname}' $gemname)
  fi

  # - jakarta
  shortname=`grep "define short_name" $file | awk '{print $3}'`
  basename=`grep "define base_name" $file | awk '{print $3}'`
  if [ "$shortname" != "" ] ; then
      if [ "$basename" != "" ] ; then
          shortname=$(expandmacros $shortname '%{base_name}' $basename)
      fi
      name=$(expandmacros $name '%{short_name}' $shortname)
  fi
  
  # - xalan-j2
  cvsversion=`grep cvs_version $file | awk '{print $3}'`

  # REAL STUFF
  mkdir -p $pkg
  if [ "$TEST" == "true" ] ; then
      echo "mv $file $pkg/$file"
  else
      mv $file $pkg/$file
      if [ "$?" -eq "0" ] ; then
          git rm -q $file
          git add $pkg/$file
      fi
  fi

  # PROCESS THE SOURCE FILES
  for (( i=0; i<${srclen}; i++));
  do
      sources[$i]=$(filefromurl ${sources[$i]})
      sources[$i]=$(expandmacros ${sources[$i]} '%{name}' $name)
      sources[$i]=$(expandmacros ${sources[$i]} '%{version}' $version)
      sources[$i]=$(expandmacros ${sources[$i]} '%{gemname}' $gemname)
      sources[$i]=$(expandmacros ${sources[$i]} '%{cvs_version}' $cvsversion)
      sources[$i]=$(expandmacros ${sources[$i]} '%{short_name}' $shortname)
      if [ "$TEST" == "true" ] ; then
          ls SOURCES/${sources[$i]}
      else
          mv SOURCES/${sources[$i]} $pkg/
          if [ "$?" -eq "0" ] ; then
              git rm -q SOURCES/${sources[$i]}
              git add $pkg/${sources[$i]}
          fi
      fi
  done

  # PROCESS THE PATCH FILES
  for (( i=0; i<${patchlen}; i++));
  do
      patches[$i]=$(filefromurl ${patches[$i]})
      patches[$i]=$(expandmacros ${patches[$i]} '%{name}' $name)
      patches[$i]=$(expandmacros ${patches[$i]} '%{version}' $version)
      patches[$i]=$(expandmacros ${patches[$i]} '%{gemname}' $gemname)
      patches[$i]=$(expandmacros ${patches[$i]} '%{cvs_version}' $cvsversion)
      if [ "$TEST" == "true" ] ; then
          ls SOURCES/${patches[$i]}
      else
          mv SOURCES/${patches[$i]} $pkg/
          if [ "$?" -eq "0" ] ; then
              git rm -q SOURCES/${patches[$i]}
              git add $pkg/${patches[$i]}
          fi
      fi
  done

done

# prep to commit
git status > /dev/null
if [ "$?" == "0" ] ; then
    msg="created project directories for each spec file:\n\n"
    for spec in ${files[@]}
    do
        msg="$msg\n$spec"
    done
    echo -e $msg | git commit -a -q -F -
    echo "files committed."
fi

titofound=0
if [ ! -d "rel-eng" ] ; then
    rc=`which tito`
    if [ "$?" == "0" ] ; then
        titofound=1
        tito init
        perl -i -pe 's/VersionTagger/ReleaseTagger/g' rel-eng/tito.props
        perl -i -pe 's/Builder/NoTgzBuilder/g' rel-eng/tito.props
    else
        echo "No 'tito' found, please install and run 'tito init'"
    fi
fi

if [ $titofound == 1 ] ; then
    echo "we found tito"
    dirs=`find . -name '*.spec' | xargs -n 1 dirname`
    for dir in ${dirs[@]}
    do
        cd $dir
        tito tag --accept-auto-changelog --auto-changelog-message="rebuild with tito"
        cd ..
    done
fi

# now report on what's left
for srcfile in SOURCES/*
do
    echo "Unused source file: $srcfile"
done
