process FETCHTOOL {

    container 'hariszaf/fetch-tool:latest'

    input:
    val reads_accession

    output:
    path("download_folder/*/raw/${reads_accession}*.fastq.gz"), emit: reads

    script:
    """
    # Make the config file #
    CONF_FILE="fetchdata-config.json"
    echo '{
    "url_max_attempts": 5,
    "ena_api_username": "",
    "ena_api_password": "",
    "aspera_bin": "/app/fetch_tool/aspera-cli/cli/bin/ascp",
    "aspera_cert": "/app/fetch_tool/aspera-cli/cli/etc/asperaweb_id_dsa.openssh"
    }' >> \$CONF_FILE

    fetch-read-tool -d download_folder/ -ru $reads_accession -c \$CONF_FILE -v
    """
}

process FETCHTOOL_RAWREADS {
    tag "$reads_accession"

    label 'process_single'

    container "/homes/timrozday/nobackup/motus_pipeline/fetchtool.sif"

    publishDir 'reads', mode: 'symlink'

    input:
    tuple val(meta), val(reads_accession)
    path fetchtool_config

    output:
    tuple val(meta), path("download_folder/*/raw/${reads_accession}*.fastq.gz"), emit: reads
    path "versions.yml"                                                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    // def prefix = task.ext.prefix ?: "$reads_accession"
    """
    fetch-read-tool -d download_folder/ -ru $reads_accession -c $fetchtool_config -v $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fetch-tool: \$(fetch-read-tool --version)
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "$reads_accession"

    """
    mkdir -p download_folder/test/raw/

    touch download_folder/test/raw/${reads_accession}.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fetch-tool: \$(fetch-read-tool --version)
    END_VERSIONS
    """
}

process FETCHTOOL_ASSEMBLY {
    tag "$assembly_accession"

    label 'process_single'

    container "microbiome-informatics/fetch-tool:v0.9.0"

    input:
    tuple val(meta), val(assembly_accession)
    path fetchtool_config

    output:
    tuple val(meta), path("download_folder/*/raw/${assembly_accession}*.fasta.gz"), emit: assembly
    path "versions.yml"                                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "$assembly_accession"
    """
    fetch-assembly-tool -d download_folder/ -as $assembly_accession -c $fetchtool_config -v $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fetch-tool: \$(fetch-assembly-tool --version)
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "$assembly_accession"
    """
    mkdir -p download_folder/test/raw/

    touch download_folder/test/raw/${assembly_accession}.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fetch-tool: \$(fetch-assembly-tool --version)
    END_VERSIONS
    """
}
