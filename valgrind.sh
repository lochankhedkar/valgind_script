valgrind_version=3.22.0
# Target linux/gnu
install_dir=${HOME}/$(whoami)/valgrind-${valgrind_version}
build_dir=/var/tmp/$(whoami)/valgrind-${valgrind_version}_build
source_dir=/var/tmp/$(whoami)/valgrind-${valgrind_version}_source
tarfile_dir=/var/tmp/$(whoami)/valgrind-${valgrind_version}_tarball


#======================================================================
# Support functions
#======================================================================


__die()
{
    echo $*
    exit 1
}


__banner()
{
    echo "============================================================"
    echo $*
    echo "============================================================"
}


__untar()
{
    dir="$1";
    file="$2"
    case $file in
        *xz)
            tar xJ -C "$dir" -f "$file"
            ;;
        *bz2)
            tar xj -C "$dir" -f "$file"
            ;;
        *gz)
            tar xz -C "$dir" -f "$file"
            ;;
        *)
            __die "don't know how to unzip $file"
            ;;
    esac
}

__remove_dir()
{
	dir_name="$1";
	if [ -d $dir_name ]; then  
		if [ -z "$(ls -A $dir_name)" ]; then
   			echo "$dir_name is Empty"
		else
   			echo "Not Empty, removing "
			rm -rfd $dir_name;
		
		fi
	else
		echo "$dir_name" doesnot exist;
	fi

}

__abort()
{
        cat <<EOF
***************
*** ABORTED ***
***************
An error occurred. Exiting...
EOF
        exit 1
}


__wget()
{
    urlroot=$1; shift
    tarfile=$1; shift

    if [ ! -e "$tarfile_dir/$tarfile" ]; then
        wget --verbose ${urlroot}/$tarfile --directory-prefix="$tarfile_dir"
    else
        echo "already downloaded: $tarfile  '$tarfile_dir/$tarfile'"
    fi
}

# Set script to abort on any command that results an error status
trap '__abort' 0
et -e

choices=( 'Fresh Install' 'Resume Install' )

# Present the choices.
# The user chooses by entering the *number* before the desired choice.
select choice in "${choices[@]}"; do

  # If an invalid number was chosen, $choice will be empty.
  # Report an error and prompt again.
  [[ -n $choice ]] || { echo "Invalid choice." >&2; continue; }

  case $choice in
    'Fresh Install')

#======================================================================
# Directory creation
#======================================================================

	__banner Creating directories

	# ensure workspace directories don't already exist
	for d in  "$build_dir" "$source_dir" ; do
	    if [ -d  "$d" ]; then
	       #__die "directory already exists - please remove and try again: $d"
	       echo "removing the directory $d"
	       __remove_dir $d
	    fi
	done

	for d in "$install_dir" "$build_dir" "$source_dir" "$tarfile_dir" ;
	do
	    test  -d "$d" || mkdir --verbose -p $d
	done


#======================================================================
# Download source code
#======================================================================


# This step requires internet access.  If you dont have internet access, then
# obtain the tarfiles via an alternative manner, and place in the
# "$tarfile_dir"

	__banner Downloading source code

	valgrind_tarfile=valgrind-${valgrind_version}.tar.bz2  

	__wget https://sourceware.org/pub/valgrind/ $valgrind_tarfile
	for f in $valgrind_tarfile
	do
	    if [ ! -f "$tarfile_dir/$f" ]; then
		__die tarfile not found: $tarfile_dir/$f
	    fi
	done


	#======================================================================
	# Unpack source tarfiles
	#======================================================================


	__banner Unpacking source code


	__untar  "$source_dir"  "$tarfile_dir/$valgrind_tarfile"

        #======================================================================
	# Clean environment
	#======================================================================


	# Before beginning the configuration and build, clean the current shell of all
	# environment variables, and set only the minimum that should be required. This
	# prevents all sorts of unintended interactions between environment variables
	# and the build process.

	__banner Cleaning environment

	# store USER, HOME and then completely clear environment
	U=$USER
	H=$HOME
	BKUP_LD_LIBRARY_PATH=$LD_LIBRARY_PATH	
	for i in $(env | awk -F"=" '{print $1}') ;
	do
	    unset $i || true   # ignore unset fails
	done

	# restore
	export USER=$U
	export HOME=$H
	export PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin
	export LD_LIBRARY_PATH=/usr/lib64:${BKUP_LD_LIBRARY_PATH}
	echo $LD_LIBRARY_PATH
	echo shell environment follows:
	env

      ;;
    'Resume Install')
      echo "Restarting installation using previously downloaded files. "
  esac

  # Getting here means that a valid choice was made,
  # so break out of the select statement and continue below,
  # if desired.
  # Note that without an explicit break (or exit) statement,
  # bash will continue to prompt./
  break

done

__banner Configuring source code

cd "${build_dir}"

    $source_dir/valgrind-${valgrind_version}/configure --prefix=${install_dir}/


#======================================================================
# Compiling
#======================================================================


cd "$build_dir"
make

# If desired, run the make test phase by uncommenting following line

#make check


#======================================================================
# Install
#======================================================================


__banner Installing

make install


#======================================================================
# Post build
#======================================================================

# Create a shell script that users can source to bring valgrind into shell
# environment
cat << EOF > ${install_dir}/activate
# source this script to bring binutils ${binutils_version} into your environment
export PATH=${install_dir}/bin:\$PATH
export LD_LIBRARY_PATH=${install_dir}/lib:${install_dir}/lib64:\$LD_LIBRARY_PATH
export MANPATH=${install_dir}/share/man/man1/:\$MANPATH
EOF

__banner Complete

trap : 0

#end
