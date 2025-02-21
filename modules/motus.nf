/*
 * mOTUs 3.0.3
 * tool that estimates relative taxonomic abundance of known
 * and currently unknown microbial community members
 * using metagenomic shotgun sequencing data.
*/

process MOTUS {

    publishDir "${params.outdir}/mOTUs/", mode: 'copy'

    label 'motus'
    tag "${sample_name}"
    container 'quay.io/biocontainers/motus:3.0.3--pyhdfd78af_0'

    input:
    tuple val(sample_name), path(reads)
    path motus_db

    output:
    val sample_name, emit: sample_name
    path "*.motus", emit: motus_result
    path "*.tsv", emit: motus_result_cleaned
    path "${reads.simpleName}_motus.log", emit: motus_log

    script:
    """
    gzip -d --force ${reads}
    echo 'Run mOTUs'

    motus profile -c -q \
    -db ${motus_db} \
    -s ${reads.baseName} \
    -t ${task.cpus} \
    -o ${reads.baseName}.motus 2>&1 | tee ${reads.simpleName}_motus.log

    echo 'clean files'
    echo -e '#mOTU\tconsensus_taxonomy\tcount' > ${reads.baseName}.tsv
    grep -v "0\$" ${reads.baseName}.motus | grep -E '^meta_mOTU|^ref_mOTU' | sort -t\$'\t' -k3,3n >> ${reads.baseName}.tsv
    tail -n1 ${reads.baseName}.motus | sed s'/-1/Unmapped/g' >> ${reads.baseName}.tsv

    LINES=\$(cat ${reads.baseName}.tsv | wc -l)
    echo 'number of lines is' \$LINES
    if [ \$LINES -eq 2 ]; then
      echo 'rename file to empty'
      mv ${reads.baseName}.tsv 'empty.motus.tsv'
    fi
    """
}

/*
 * Download MGnify Rfam DB
*/
process MOTUS_DOWNLOAD_DB {

    publishDir "${params.databases.cache_path}", mode: 'copy'
    
    label 'motus_download'
    container "quay.io/biocontainers/motus:3.0.3--pyhdfd78af_0"

    output:
        path "db_mOTU", emit: db_dir
        path "db_mOTU/*", emit: db

    script:
    """
    ## must copy script file to working directory,
    ## otherwise the reference_db will be download to bin folder
    ## other than current directory
    ## NOTE: container required
    cp /usr/local/lib/python3.9/site-packages/motus/downloadDB.py downloadDB.py
    python downloadDB.py -t $task.cpus
    # mv db_mOTU/* .
    # rm -r db_mOTU/
    rm downloadDB.py
    """
}
