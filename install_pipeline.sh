#!/bin/bash

# Metagenomics Pipeline installer
# S Sturrock - ESR (modified by M Storey)
# 30/07/2021

# get the path of the repo
INSTALL_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "$INSTALL_SCRIPT_DIR"


# hard code for debugging (k database will go here)
SSD_MOUNT="/media/1tb_nvme"

# get user input for database location
# uncomment below 
#echo 'Enter the SSD mount path to install the pipeline to:'
#read -p '(e.g. /media/minit/xavierSSD ): ' SSD_MOUNT

if [ ! -d $SSD_MOUNT ]
then
    echo "Invalid location, please try again"
    exit 0
fi

#set up a dir to install deps into

BIN="$INSTALL_SCRIPT_DIR/bin"
[ ! -d $BIN ] && mkdir $BIN


echo "Installing dependancies"
echo ""
# Install filtlong before the activation of conda envor it doesn't work 
echo ""
echo "Install filtlong"
echo ""
cd $BIN
git clone https://github.com/rrwick/Filtlong.git
cd Filtlong
make -j
cd $INSTALL_SCRIPT_DIR


# following assumes conda is installed on the system, add this to README.md
echo "Setting up the conda environment"
# needed to use conda in a script
eval "$(command conda 'shell.bash' 'hook' 2> /dev/null)"

echo "Installing mamba in base environment"
conda install -y -q -c conda-forge mamba

echo "Making a conda env called: POx-POC_conda"
# Make empty conda env with the right name
conda create -y -q -n POx-POC_conda

echo "Installing dependancies with mumba"
mamba env update -q -n POx-POC_conda --file environment.yml

# activate that new env 
conda activate POx-POC_conda


# bulid some stuff from source in the bin dir required for rcf, this needs biopython from the conda env
echo ""
echo "Clone the rcf repo to run retaxdump"
echo ""
cd $BIN
git clone https://github.com/khyox/recentrifuge.git
cd recentrifuge
# Download NCBI node db
./retaxdump


# Download and build kraken2
echo ""
echo "Download and build kraken2"
echo ""
cd $BIN
git clone https://github.com/DerrickWood/kraken2.git
cd kraken2
./install_kraken2.sh


# Create init.sh to set up path etc for user
#touch init.sh
#chmod init.sh

# R stuff shoud be installed with conda/mumba from env.yaml file
# recent version of fontawesome isn't available in conda
R -e "install.packages('fontawesome', repos='http://cran.rstudio.com/')"

# Need to set up the minikraken database
# put the mini-kraken2 database on the SSD.
K_DATABASE="${SSD_MOUNT}/kraken2_DBs"


if [ ! -f "${K_DATABASE}/minikraken2_v2_8GB_201904.tgz" ]; then
	echo "Kraken2 index database will be downloaded to: ${K_DATABASE}"
	# DL the databases 
	wget https://genome-idx.s3.amazonaws.com/kraken/minikraken2_v2_8GB_201904.tgz -P $K_DATABASE
	# unpack the .tgz
	cd $K_DATABASE
	tar -xvzf minikraken2_v2_8GB_201904.tgz
else
	echo "The Kraken database already exists. Skipping download"
fi


# ### The following needs the most work. Need a cleaner way to do this ###

# # #add stuff to path via init.script 
# # echo "export PATH=${INSTALL_DIR}/bin:${INSTALL_DIR}/bin/scripts:${INSTALL_DIR}/bin/dashboard:${INSTALL_DIR}/bin/dashboard/dashboard.Rmd:${PATH}" >> $INSTALL_DIR/bin/init.sh

# # # add some environmental vars (must be a better way to do this)
# # echo "export RCF_TAXDUMP=${INSTALL_DIR}/recentrifuge/taxdump" >> $INSTALL_DIR/bin/init.sh

# # echo "export KRAKEN2_DB_PATH=${K_DATABASE}/minikraken2_v2_8GB_201904_UPDATE" >> $INSTALL_DIR/bin/init.sh

# # # might need to add some conda stuff here for the launch script
# # echo "export CONDA_PATH=${INSTALL_DIR}/miniconda/etc/profile.d/conda.sh" >> $INSTALL_DIR/bin/init.sh

# # # this sucks, needs fixing
# # cat $INSTALL_DIR/bin/init.sh >> ~/.bashrc