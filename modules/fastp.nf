
process FASTP {

    publishDir "${params.outdir}/qc/fastp", mode: 'copy', pattern: "*html"
    publishDir "${params.outdir}/qc/fastp", mode: 'copy', pattern: "*json"
    publishDir "${params.outdir}/qc", mode: 'copy', pattern: "*fastq*"

    container 'quay.io/biocontainers/fastp:0.23.1--h79da9fb_0'
    label 'fastp'
    tag "$sample_name"

    input:
    val sample_name
    file reads_list
    val mode
    val merged_reads

    output:
    val sample_name, emit: sample_name
    path "${sample_name}_fastp*.fastq.gz", optional: true, emit: output_reads
    path "*_fastp.json", emit: json
    path "*_fastp.html", emit: html
    path "*_merged*", optional: true, emit: overlapped_reads

    script:
    /* Handle the input reads */
    def input_reads = "";
    def output_reads = "";
    def report_name = "qc";

    if ( mode == "single" ) {
        input_reads = "--in1 ${reads_list}";
        output_reads = "--out1 ${sample_name}_fastp.fastq.gz";
    }

    if ( mode == "paired" ) {
        input_reads = "--in1 ${reads_list[0]} --in2 ${reads_list[1]} --detect_adapter_for_pe";
        output_reads = "--out1 ${sample_name}_fastp_1.fastq.gz --out2 ${sample_name}_fastp_2.fastq.gz";
    }

    /* Optional parameters */
    def args = ""
    if ( merged_reads ) {
        args += " -m --merged_out ${sample_name}_${merged_reads}" +
        " --unpaired1 ${sample_name}.unpaired_1.fastq.gz " +
        " --unpaired2 ${sample_name}.unpaired_2.fastq.gz"
        report_name = "overlap"
    }
    args += params.fastp_params.length_filter ? " -l ${params.fastp_params.length_filter}" : "";
    args += params.fastp_params.polya_trim ? " -x ${params.fastp_params.polya_trim}" : "";
    args += params.fastp_params.qualified_quality_phred ? " -q ${params.fastp_params.qualified_quality_phred}" : "";
    args += params.fastp_params.unqualified_percent_limit ? " -u ${params.fastp_params.unqualified_percent_limit}" : "";

    """
    fastp -w ${task.cpus} \
    ${input_reads} \
    ${output_reads} \
    --json ${sample_name}_${report_name}_fastp.json \
    --html ${sample_name}_${report_name}_fastp.html \
    ${args}
    """
}
