#!/bin/bash

# This script replaces the Octane binary "cap_gen" for use on R700-based
# devices. It aims to mimic the behavior of the Octane binary.
#
# Notable differences include: 
#   * Uses Rauc underneath the hood rather than the custom UPG format.
#   * Error messages and exit codes may differ significantly.
#   * Some CAP description fields are no longer needed.
#   * Rauc only has a single compatible string, so there can only be a single
#     'Valid Reader Hardware' field setting.

SCRIPT_DIR=$( cd $( dirname ${BASH_SOURCE[0]}) && pwd )
SCRIPT_PATH=$SCRIPT_DIR/cap_gen.sh
ETK_VERSION_FILE=$SCRIPT_DIR/VERSION

###################
# Logging helpers #
###################

fail() {
    # Arg1: message to print
    echo "ERROR: $1"
    exit 1
}

warn() {
    echo "WARNING: $1"
}

vlog() {
    [ -n "$VERBOSE" ] && echo "DEBUG: $1"
}

run_cmd() {
    # Run command. Log it verbosely if it failed, or if the verbose flag is set.
    cmd=$@

    vlog "[exec] $cmd"
    cmd_output=$($cmd 2>&1)
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "ERROR: Command '$cmd' failed with '$exit_code'"
        echo "$cmd_output"
        exit $exit_code
    fi
}

###############################
# Input parsing, script usage #
###############################

print_usage() {
    echo "Usage: $SCRIPT_PATH [-v] [<-d file -o file [-f {mkfs|fstool}]> | <-i file> | -V]
  -v                Output verbose information
  -d file           The upgrade description file to use for settings
  -f {mkfs|fstool}  The external tool to use for filesystem generation
  -o file           The output file to write
  -i file           The image file to inspect and display metadata
  -k directory      The directory containing private key and cert for signing.
                    The directory should contain cap.key.pem and cap.cert.pem.
  -n                Generate new private key and cert for signing.
  -V                Output version information"
}

process_args() {
    [ -n "$FS_GEN_TOOL" ] && warn "Ignoring deprecated '-f' option"

    if [ -n "$DESC_FILE" -o -n "$OUTPUT_FILE" ]; then
        # Creating a bundle
        [ -n "$DESC_FILE" -a -n "$OUTPUT_FILE" ] || fail "Must specify both '-d' and '-o'"
        [ -n "$INPUT_FILE" ] && fail "Can't specify '-d' or '-o' along with '-i'"
        [ -f "$DESC_FILE" ] || fail "Upgrade description file '$DESC_FILE' does not exist"
        [ -n "$OUTPUT_FILE" -a -d "$(dirname $OUTPUT_FILE)" ] || fail "'$OUTPUT_FILE' already exists"
        BUNDLE_CREATE=1
    elif [ -n "$INPUT_FILE" ]; then
        # Inspecting a bundle
        [ -f "$INPUT_FILE" ] || fail "'$INPUT_FILE' does not exist"
        BUNDLE_INFO=1
    elif [ -z "$DUMP_VERSION" ]; then
        print_usage
        fail "No command line options specified."
    fi
}

map_setting() {
    # $1 = key
    # $2 = value
    # Needs the following:
    #   Input Directory = ./path/
    #   Version = 1.2.3.4
    #   Valid Reader Hardware = R700
    vlog "[func] map_setting($1,$2)"
    [ -n "$1" -o -n "$2" ] || fail "map_setting called with unexpected paramter"

    case "$1" in
        "Persistent Data")       PERSISTENT_DATA="$2";;
        "Version")               CAP_VERSION="$2";;
        "Valid Reader Hardware") VALID_READER_HW="$2";;
        "Input Directory")       CAP_SOURCE="$2";;
        "Encrypt")               ENCRYPT="$2";;
        "Recipients")            RECIPIENTS="$2";;
        *) warn "Ignoring unknown setting '$1 = $2'";;
    esac 
}

parse_description() {
    vlog "[func] parse_description"

    stripped_file=$(grep "^[^#\[]" $DESC_FILE | grep ".*\ =\ .*")
    readarray -t settings <<< "$stripped_file"
    for setting in "${settings[@]}"; do
        key="${setting% = *}"
        val="${setting#* = }"
        vlog "Parsing description '$setting' as { '$key' : '$val' }"
        map_setting "$key" "$val"
    done

    [ -n "$CAP_VERSION" ] || fail "'Version' field not set in '$DESC_FILE'"
    [ -n "$CAP_SOURCE" ] || fail "'Input Directory' field not set in '$DESC_FILE'"
    case "$VALID_READER_HW" in
        "R700") ;&
        "R510") ;&
        "R515") ;&
        "R***") vlog "Valid Reader Hardware '$VALID_READER_HW' is valid" ;;
        *) fail "Setting Valid Reader Hardware to '$VALID_READER_HW' is invalid" ;;
    esac

    # ensure that encrypt flag is valid
    if [ -n $ENCRYPT ]; then
        case "$ENCRYPT" in
            "1")  ENCRYPT="True" ;;
            "True")  ;;
            *) ENCRYPT="False"; warn "Disabling CAP encryption.";;
        esac
    else
        $ENCRYPT="False"
    fi

    true  # just make sure the function doesn't fail
}

############################
# Rauc wrapper and friends #
############################

check_tools() {
    # Check for host tools that are needed to make the magic happen.
    HOST_DIR=$SCRIPT_DIR/arm-toolchain
    BIN=$HOST_DIR/bin
    SBIN=$HOST_DIR/sbin

    RAUC=$BIN/rauc

    RAUC_CERT=$HOST_DIR/share/signing/cap.cert
    RAUC_KEY=$HOST_DIR/share/signing/cap.key
    RAUC_KEYRING=$HOST_DIR/share/signing/ca-bundle.crt

    if [ -n "$KEY_DIR" ]; then
        RAUC_CERT="$KEY_DIR/cap.cert.pem"
        RAUC_KEY="$KEY_DIR/cap.key.pem"
        RAUC_KEYRING="$RAUC_CERT"
    elif [ -n "$GEN_KEY" ]; then
        RAUC_CERT=cap.cert.pem
        RAUC_KEY=cap.key.pem
        RAUC_KEYRING="$RAUC_CERT"
    fi

    FALLOCATE=$BIN/fallocate
    MKFS=$SBIN/mkfs.ext4
    E2FSCK=$SBIN/e2fsck

    # Test that tools exist
    fail=0
    for bin in mkdir cat $FALLOCATE $MKFS $E2FSCK $RAUC; do
        which $bin > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "ERROR: Required binary '$bin' not found"
            fail=1
        fi
    done
    [ $fail -ne 0 ] && exit 1
}

bundle_create_cleanup() {
    vlog "[func] bundle_create_cleanup"
    if [ -n "$tmpdir" ]; then
        grep -q "$tmpdir/cap_mount" /proc/mounts && sudo umount $tmpdir/cap_mount
        rm -rf $tmpdir
    fi
}

bundle_create() {
    vlog "[func] bundle_create"

    # Register cleanup tasks
    trap bundle_create_cleanup EXIT

    tmpdir=$(mktemp -d)
    vlog "Working in tmpdir '$tmpdir'"

    # Create and mount FS
    run_cmd $FALLOCATE -l $((128*1024*1024)) $tmpdir/cap.ext4
    run_cmd $MKFS -d $CAP_SOURCE/ $tmpdir/cap.ext4
    run_cmd $E2FSCK -n -f $tmpdir/cap.ext4

    bundle_format=""
    if [ $ENCRYPT = "True" ]; then
        bundle_format="
[bundle]
format=crypt
        "
    fi

    # Create Rauc manifest file
    cat >> $tmpdir/manifest.raucm << EOF
[update]
compatible=$VALID_READER_HW
version=$CAP_VERSION

$bundle_format

[hooks]
filename=cap-hook.sh
hooks=install-check

[image.customer]
filename=cap.ext4
hooks=post-install
EOF

    # Create CAP hook script
    cat >> $tmpdir/cap-hook.sh << EOF
#!/bin/sh

case "\$1" in
    slot-post-install)
        if [ \$RAUC_SLOT_CLASS == "customer" ]; then
            touch /tmp/cap_installing
            if [ -n "$PERSISTENT_DATA" ]; then
                PERSIST_SRC=/cust/$PERSISTENT_DATA
                PERSIST_DST=\$RAUC_SLOT_MOUNT_POINT/$PERSISTENT_DATA
                if [ -f "\$PERSIST_SRC" ]; then
                    systemctl stop cap.service
                    mkdir -p \$(dirname \$PERSIST_DST)
                    cp -p \$PERSIST_SRC \$PERSIST_DST
                elif [ -d "\$PERSIST_SRC" ]; then
                    systemctl stop cap.service
                    mkdir -p \$PERSIST_DST
                    cp -prT \$PERSIST_SRC \$PERSIST_DST
                fi
            fi
        fi
        ;;
    install-check)
        logger -t cap-hook -p user.info "\$1: System \$RAUC_SYSTEM_COMPATIBLE, Manifest \$RAUC_MF_COMPATIBLE"
        if [ \$RAUC_MF_COMPATIBLE == "R***" ]; then
            :         # Compatible
        elif [ \$RAUC_MF_COMPATIBLE == \$RAUC_SYSTEM_COMPATIBLE ]; then
            :         # Compatible
        else
            logger -t cap-hook -p user.error "\$1: Not compatible! System \$RAUC_SYSTEM_COMPATIBLE, Manifest \$RAUC_MF_COMPATIBLE"
            exit 10   # Incompatible
        fi
        ;;
    *)
        exit 1
        ;;
esac

exit 0
EOF
    chmod +x $tmpdir/cap-hook.sh

    # Generate signing keys
    if [ -n "$GEN_KEY" ]; then
        openssl req -x509 -config $HOST_DIR/etc/ssl/openssl.cnf -newkey rsa:4096 -nodes -keyout cap.key.pem -out cap.cert.pem -subj "/CN=CAP" -days 10000
    fi

    # Don't specify keyring when using self signed keys
    if [ -n "$RAUC_KEYRING" ]; then
        RAUC_KEYRING_CMD="--keyring $RAUC_KEYRING"
    fi

    # Finally call Rauc
    rm -f $OUTPUT_FILE
    run_cmd $RAUC --cert $RAUC_CERT --key $RAUC_KEY $RAUC_KEYRING_CMD bundle $tmpdir/ $OUTPUT_FILE

    # if we encrypt the bundle, create a temporary PEM file containing all recipient keys and call rauc again
    if [ $ENCRYPT = "True" ]; then
        if [ -n "$RECIPIENTS" ]; then
            cat $RECIPIENTS > $tmpdir/recipients.pem
            run_cmd $RAUC encrypt --to $tmpdir/recipients.pem $RAUC_KEYRING_CMD $OUTPUT_FILE $OUTPUT_FILE.enc
            # we do NOT want to leave the plaintext CAP behind, so it is replaced with the encrypted bundle
            mv $OUTPUT_FILE.enc $OUTPUT_FILE
        else
            echo "ERROR: List of Recipients is empty!"
            exit 11
        fi
    fi
}

bundle_info() {
    rauc_info=$($RAUC --keyring $RAUC_KEYRING info --output-format=shell $INPUT_FILE)

    readarray -t info <<< "$rauc_info"
    for setting in "${info[@]}"; do
        key="${setting%=*}"
        val="${setting#*=}"
        val=${val#"'"}
        val=${val%"'"}
        vlog "Parsing description '$setting' as { '$key' : '$val' }"

        # Settings to save for later
        [ "$key" = "RAUC_MF_COMPATIBLE" ] && rauc_compat="$val"
        [ "$key" = "RAUC_MF_VERSION" ] && rauc_version="$val"
    done

    echo "Partition START
  ValidHardware[00]      : $rauc_compat
  FirmwareVersion        : $rauc_version
  Partition              : CAP"
}

dump_version() {
    echo "$SCRIPT_PATH version "` cat $ETK_VERSION_FILE`
}

##########
#  MAIN  #
##########

while getopts "d:f:k:o:i:nVv" arg; do
    case "$arg" in
      d) DESC_FILE="$OPTARG";;
      f) FS_GEN_TOOL="$OPTARG";;
      k) KEY_DIR="$OPTARG";;
      o) OUTPUT_FILE="$OPTARG";;
      i) INPUT_FILE="$OPTARG";;
      n) GEN_KEY=1;;
      V) DUMP_VERSION=1;;
      v) VERBOSE=1;;
      \?) print_usage && exit 1;;
      *) print_usage && exit 1;;
    esac
done

process_args
check_tools

[ -n "$DUMP_VERSION" ] && dump_version
[ -n "$BUNDLE_CREATE" ] && parse_description && bundle_create
[ -n "$BUNDLE_INFO" ] && bundle_info

exit 0
