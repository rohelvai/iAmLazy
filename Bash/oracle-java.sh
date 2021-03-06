#!/bin/bash
###
# File: oracle-java.sh
# Created: Monday, 17th February 2020 3:35:06 pm
# Author: Rakibul Yeasin (ryeasin03@gmail.com)
# -----
# Last Modified: Monday, 17th February 2020 4:37:54 pm
# Modified By: Rakibul Yeasin (ryeasin03@gmail.com)
# -----
# Copyright (c) 2020 Slishee
###


java_dist="jdk-8u241-linux-x64.tar.gz"
java_dir="/usr/lib/jvm"
java_installed_dir="$java_dir/jdk1.8.0_241"

# Make sure the script is running as root.
if [ "$UID" -ne "0" ]; then
    echo "You must be root to run $0. Try following"
    echo "sudo $0"
    exit 9
fi

function create_shortcut() {
    shortcut_file="$applications_dir/jmc_$jdk_major_version.desktop"
    cat <<EOF >$shortcut_file
[Desktop Entry]
Name=Java $jdk_major_version: JMC
Comment=Oracle Java Mission Control for Java $jdk_major_version
Type=Application
Categories=Utility;Development;IDE;
Exec=$extracted_dirname/bin/jmc
Icon=$extracted_dirname/lib/missioncontrol/icon.xpm
Terminal=false
EOF
    chmod +x $shortcut_file
}

function install() {
    # wget "https://cdn-33.anonfile.com/Zak01daco9/efe3d851-1581936292/jdk-8u241-linux-x64.tar.gz" -O $java_dist
    # Create Java Installation directory
    mkdir -p $java_dir

    # Check Java executable
    java_exec="$(tar -tzf $java_dist | grep ^[^/]*/bin/java$ || echo "")"
    if [[ -z $java_exec ]]; then
        echo "Could not find \"java\" executable in the distribution. Please specify a valid Java distribution."
        exit 1
    fi

    # JDK Directory with version
    jdk_dir="$(echo $java_exec | cut -f1 -d"/")"
    extracted_dirname=$java_dir"/"$jdk_dir

    # Extract Java Distribution
    if [[ ! -d $extracted_dirname ]]; then
        echo -e "Extracting $java_dist to $java_dir"
        tar -xof $java_dist -C $java_dir
        echo "JDK is extracted to $extracted_dirname"
    else
        echo "WARN: JDK was not extracted to $java_dir. There is an existing directory with name $jdk_dir."
        exit 1
    fi

    if [[ ! -f "${extracted_dirname}/bin/java" ]]; then
        echo "ERROR: The path $extracted_dirname is not a valid Java installation."
        exit 1
    fi

    # Oracle JDK: 7 to 8
    java_78_dir_regex="^jdk1\.([0-9]*).*$"

    # JDK Major Version
    jdk_major_version=""

    if [[ $jdk_dir =~ $java_78_dir_regex ]]; then
        jdk_major_version=$(echo $jdk_dir | sed -nE "s/$java_78_dir_regex/\1/p")
    else
        jdk_major_version=$(echo $jdk_dir | sed -nE "s/$java_9up_dir_regex/\1/p")
    fi

    # Run update-alternatives commands
    echo "Running update-alternatives..."
    declare -a commands=($(ls -1 ${extracted_dirname}/bin))
    for command in "${commands[@]}"; do
        command_path=$extracted_dirname/bin/$command
        if [[ -x $command_path ]]; then
            update-alternatives --install "/usr/bin/$command" "$command" "$command_path" 10000
            update-alternatives --set "$command" "$command_path"
        fi
    done

    lib_path=$extracted_dirname/jre/lib/amd64/libnpjp2.so
    if [[ -d "/usr/lib/mozilla/plugins/" ]] && [[ -f $lib_path ]]; then
        update-alternatives --install "/usr/lib/mozilla/plugins/libjavaplugin.so" "mozilla-javaplugin.so" "$lib_path" 10000
        update-alternatives --set "mozilla-javaplugin.so" "$lib_path"
    fi

    # Create system preferences directory
    java_system_prefs_dir="/etc/.java/.systemPrefs"
    if [[ ! -d $java_system_prefs_dir ]]; then
        if (confirm "Create Java System Prefs Directory ($java_system_prefs_dir) and change ownership to $SUDO_USER:$SUDO_USER?"); then
            echo "Creating $java_system_prefs_dir"
            mkdir -p $java_system_prefs_dir
            chown -R $SUDO_USER:$SUDO_USER $java_system_prefs_dir
        fi
    fi

    if grep -q "export JAVA_HOME=.*" $HOME/.bashrc; then
        sed -i "s|export JAVA_HOME=.*|export JAVA_HOME=$extracted_dirname|" $HOME/.bashrc
    else
        echo "export JAVA_HOME=$extracted_dirname" >>$HOME/.bashrc
    fi
    source $HOME/.bashrc

    applications_dir="$HOME/.local/share/applications"

    if [[ -d $applications_dir ]] && [[ -f $extracted_dirname/bin/jmc ]]; then
        create_shortcut
    fi

    rm $java_dist
}

function uninstall() {
    echo "Uninstalling: $java_installed_dir"

    # Run update-alternatives commands
    echo "Running update-alternatives..."
    declare -a commands=($(ls -1 ${java_installed_dir}/bin))
    for command in "${commands[@]}"; do
        command_path="$java_installed_dir/bin/$command"
        if [[ -x $command_path ]]; then
            update-alternatives --remove "$command" "$command_path"
        fi
    done

    lib_path="$java_installed_dir/jre/lib/amd64/libnpjp2.so"
    if [[ -d "/usr/lib/mozilla/plugins/" ]] && [[ -f $lib_path ]]; then
        update-alternatives --remove "mozilla-javaplugin.so" "$lib_path"
    fi

    rm -rf $java_installed_dir

    jdk_major_version=""

    if [[ $java_installed_dir =~ .*jdk1\.([0-9]*).* ]]; then
        jdk_major_version=$(echo $java_installed_dir | sed -nE 's/.*jdk1\.([0-9]*).*/\1/p')
    elif [[ $java_installed_dir =~ .*jdk-([0-9]*).* ]]; then
        jdk_major_version=$(echo $java_installed_dir | sed -nE 's/.*jdk-([0-9]*).*/\1/p')
    fi

    applications_dir="$HOME/.local/share/applications"
    jmc_shortcut_file="$applications_dir/jmc_$jdk_major_version.desktop"

    if [ -f $jmc_shortcut_file ]; then
        rm $jmc_shortcut_file
    fi
    echo "Uninstallation done!!!"
}

if [[ $1 == 'i' ]]; then
    install
elif [[ $1 == 'u' ]]; then
    uninstall
else
    echo "To install oracle-java-8 run 'sudo $0 i'"
    echo "To uninstall oracle-java-8 run 'sudo $0 u'"
    exit 9
fi