process FETCH_URL {
    tag "$sample_name"

    label 'process_single'
    container 'quay.io/biocontainers/gnu-wget:1.18--hb829ee6_10'

    publishDir "${params.reads_cache_path}", mode: 'copy'
    errorStrategy 'retry'

    input:
    tuple val(sample_name), val(url), val(md5), val(read_type)

    output:
    tuple val(sample_name), path("${sample_name}/${fn}"), val(read_type)

    script:
    fn = url.tokenize('/').last()
    checksum_cmd = ''
    // if(!(md5=='')) {
    //     checksum_cmd = """
    //                    if \$dl_md5 -nq $md5; then
    //                        exit 5
    //                    fi
    //                    """
    // }
    """
    mkdir -p ${sample_name}
    wget ${url} -O ${sample_name}/${fn}
    # dl_md5="\$(cat $sample_name/$fn | md5sum | awk '{print \$1}')"
    ${checksum_cmd}
    """
}
