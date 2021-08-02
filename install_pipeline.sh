#!/bin/bash

# Metagenomics Pipeline installer
# S Sturrock - ESR
# 30/07/2021


PIPELINE=POX_POC_install
# get the path of the repo
INSTALL_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# get user input for database location
echo 'Enter the SSD mount path to install the pipeline to:'
read -p '(e.g. /media/minit/xavierSSD ): ' SSD_MOUNT

if [ ! -d $SSD_MOUNT ]
then
    echo "Invalid location, please try again"
    exit 0
fi


# User can specify destination; default is supplied SSD mount 
if [ $# -lt 1 ]; then
	INSTALL_DIR=${SSD_MOUNT}/${PIPELINE}
else
	INSTALL_DIR=${1}/${PIPELINE}
fi


# If the directory already exists, delete it
if [ -d $INSTALL_DIR ]; then
	rm -rf $INSTALL_DIR
fi

mkdir -p $INSTALL_DIR/bin
# Go into install directory and everything will be put in here
cd $INSTALL_DIR

# Download and build kraken2
echo "Download and build kraken2"
echo ""
git clone https://github.com/DerrickWood/kraken2.git
cd kraken2
./install_kraken2.sh $INSTALL_DIR/bin

K_DATABASE="${INSTALL_DIR}/kraken2/kraken2_DBs"
echo "Kraken2 index database will be downloaded to: ${K_DATABASE}"


# Create init.sh to set up path etc for user
echo "export PATH=${INSTALL_DIR}/bin:${PATH}" > $INSTALL_DIR/bin/init.sh
chmod +x $INSTALL_DIR/bin/init.sh


# Install filtlong
echo "Install filtlong"
echo ""
cd $INSTALL_DIR
git clone https://github.com/rrwick/Filtlong.git
cd Filtlong
make -j
mv bin/filtlong $INSTALL_DIR/bin
cd $INSTALL_DIR

# Set up miniconda
mkdir $INSTALL_DIR/miniconda
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh
bash Miniconda3-latest-Linux-aarch64.sh -b -f -p $INSTALL_DIR/miniconda
# Add miniconda to the init.sh
echo 'eval "$('$INSTALL_DIR'/miniconda/bin/conda shell.bash hook)"' >> $INSTALL_DIR/bin/init.sh

# Activate the conda env
eval "$(${INSTALL_DIR}/miniconda/bin/conda shell.bash hook)"
# Add channels
# conda config --add channels defaults
conda config --add channels bioconda
conda config --add channels conda-forge
# Mamba
conda install -y mamba -n base -c conda-forge

# recentrifuge install
mamba install -y -c bioconda recentrifuge
cd $INSTALL_DIR
git clone https://github.com/khyox/recentrifuge.git
cd recentrifuge
# Download NCBI node db
./retaxdump

# Install R
mamba create -y -n r_env r-essentials r-base
mamba install -y -c conda-forge r-shinylp
mamba install -y -c conda-forge r-dt
conda install -y -c conda-forge r-flexdashboard
conda install -y -c conda-forge r-here
conda install -y -c conda-forge r-plotly
#mamba install -c conda-forge r-fontawesome
# recent version of fontawesome isn't available in conda
R -e "install.packages('fontawesome', repos='http://cran.rstudio.com/')"

# Install seaborn
pip3 install seaborn

#Need to set up the minikraken database
if [ ! -f "${K_DATABASE}/minikraken2_v2_8GB_201904.tgz" ]; then
	# DL the databases 
	wget https://genome-idx.s3.amazonaws.com/kraken/minikraken2_v2_8GB_201904.tgz -P $K_DATABASE
	# unpack the .tgz
	cd $K_DATABASE
	tar -xvzf minikraken2_v2_8GB_201904.tgz 
fi

cd $INSTALL_DIR
# cp the run script and dashboard script to the pipeline bin dir so it will be in PATH
cp $INSTALL_SCRIPT_DIR/scripts/POX-POC_run.py $INSTALL_DIR/bin
cp $INSTALL_SCRIPT_DIR/scripts/launch_dashboard.sh $INSTALL_DIR/bin

echo "export RCF_TAXDUMP=${INSTALL_DIR}/recentrifuge/taxdump" >> $INSTALL_DIR/bin/init.sh

echo "export KRAKEN2_DB_PATH=${K_DATABASE}/minikraken2_v2_8GB_201904_UPDATE" >> $INSTALL_DIR/bin/init.sh

# might need to add some conda stuff here for the launch script
echo "export CONDA_PATH=${INSTALL_DIR}/miniconda/etc/profile.d/conda.sh" >> $INSTALL_DIR/bin/init.sh


# this is not good practice, add the init.sh to the ~/.bashrc
if [ ! $KRAKEN2_DB_PATH ]
then
	cat $INSTALL_DIR/bin/init.sh >> ~/.bashrc
fi

