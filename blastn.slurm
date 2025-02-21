#!/bin/bash
#SBATCH --job-name=lyon_pilot_all_core_nt
#SBATCH --array=1-110
#SBATCH --partition=shared
#SBATCH --time=0-24:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --error=slurm_logs/lyon_pilot_blast_all-%A_%a.err
#SBATCH --output=slurm_logs/lyon_pilot_blast_all-%A_%a.out
#SBATCH --mail-type=BEGIN,END,FAIL,REQUEUE,TIME_LIMIT_80
#SBATCH --mail-user=kylieph@hawaii.edu

##Check if slurm_logs directory exists, create it if not
SLURM_LOG_DIR=~/eem_group/bryo_arthro/lyon_pilot/slurm_logs
BLAST_OUTPUT_DIR=~/eem_group/bryo_arthro/lyon_pilot/all_blast_output

[[ -d "$SLURM_LOG_DIR" ]] || mkdir -p "$SLURM_LOG_DIR"
[[ -d "$BLAST_OUTPUT_DIR" ]] || mkdir -p "$BLAST_OUTPUT_DIR"


##Temporarily mount BLAST database directory if it doesn’t already exist
if [[ ! -d "/tmp/blastdb" ]]; then
    mkdir /tmp/blastdb
    squashfuse_ll -o timeout=43200 /mnt/lustre/koa/container/blast/ncbi_latest.sqfs /tmp/blastdb/
    if [[ ! -d "/tmp/blastdb" ]]; then
        echo "Error: BLAST database mount failed!"
        exit 1
    fi
fi

##Add taxonomy file to tmp/blastdb
if [[ ! -f "/tmp/blastdb/taxdb.btd" || ! -f "/tmp/blastdb/taxdb.bti" ]]; then
    cd /tmp/blastdb
    wget -q https://ftp.ncbi.nlm.nih.gov/blast/db/taxdb.tar.gz
    tar -xzf taxdb.tar.gz
    rm taxdb.tar.gz  # Clean up after extraction
fi

##Clear then load correct module
module purge
module load bio/BLAST+/2.13.0-gompi-2022a

##Define BLAST database directory
export BLASTDB="/tmp/blastdb"

##Get input file for the current array task
fid=$(sed -n "$SLURM_ARRAY_TASK_ID"p ~/lyon_pilot_asvs_split.lst)
filename=$(basename "$fid")

##Check if fid is empty
if [[ -z "$fid" ]]; then
    echo "Error: No input file found for task ID $SLURM_ARRAY_TASK_ID"
    exit 1
fi

##Run blastn with the selected input file
blastn -db /tmp/blastdb/core_nt \
    -query "$fid" \
    -outfmt "6 qseqid qlen sseqid pident length qstart qend sstart send evalue bitscore staxids" \
    -max_target_seqs 10 \
    -perc_identity 85 \
    -num_threads $SLURM_CPUS_PER_TASK \
    -out "$BLAST_OUTPUT_DIR/${filename}_blast_all_results.out"
