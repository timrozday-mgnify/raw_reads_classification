/*
 * Quality control, host-decontamination and overlap reads
 */

include { FASTP } from '../modules/fastp'
include { SEQPREP } from '../modules/seqprep'
include { SEQPREP_REPORT } from '../modules/seqprep'
include { QC_REPORT } from '../modules/create_qc_report'
include { DECONTAMINATION } from '../modules/decontamination'
include { DECONTAMINATION_REPORT } from '../modules/decontamination'
include { SEQTK as FASTQ_TO_FASTA} from '../modules/seqtk'
include { QC_STATS } from '../modules/qc_summary'

workflow QC {
    take:
        sample
        ref_genome_dir
    
    main:
        
        FASTP(
            sample.map{ it.meta.id },
            sample.map{ it.reads.reads },
            sample.map{ it.mode },
            Channel.value("")
        )
       
        decontam_ch = FASTP.out.sample_name.merge(FASTP.out.output_reads).map{ tuple(it[0],it[1..-1]) }.join(sample.map{tuple(it.meta.id, it)})
        // decontam_ch.view{ "decontam_ch - ${it}" }

        DECONTAMINATION(
            decontam_ch.map{ it[1] },
            ref_genome_dir,
            decontam_ch.map{ it[2].mode },
            decontam_ch.map{ it[0] },
        )
        
        decontam_reads_ch = DECONTAMINATION.out.sample_name.merge(DECONTAMINATION.out.decontaminated_reads).map{ tuple(it[0],it[1..-1]) }.join(sample.map{tuple(it.meta.id, it)})
        // decontam_reads_ch.view{ "decontam_reads_ch - ${it}" }

        DECONTAMINATION_REPORT(
            decontam_reads_ch.map{ it[0] },
            decontam_reads_ch.map{ it[2].mode },
            decontam_reads_ch.map{ it[1] }
        )

        // branch here
        seqrep_ch = decontam_reads_ch.branch{ 
            paired: it[2].mode=='paired'
            single: it[2].mode=='single'
        }
        
        SEQPREP(
            seqrep_ch.paired.map{ it[0] },
            seqrep_ch.paired.map{ it[1] }
        )
        SEQPREP_REPORT(
            SEQPREP.out.sample_name,
            SEQPREP.out.forward_unmapped_reads,
            SEQPREP.out.reverse_unmerged_reads,
            SEQPREP.out.overlapped_reads
        )

        paired_overlapped_reads_ch = SEQPREP.out.sample_name.merge(SEQPREP.out.overlapped_reads).map{ tuple(it[0],it[1..-1]) }
        paired_overlapped_counts_ch = SEQPREP_REPORT.out.sample_name.merge(SEQPREP_REPORT.out.overlapped_report)
        single_overlapped_reads_ch = seqrep_ch.single.map{ tuple(it[0],it[1]) }
        single_overlapped_counts_ch = seqrep_ch.single.map{ it[0] }.merge(Channel.fromPath("NO_FILE"))
        overlapped_counts = paired_overlapped_counts_ch.mix(single_overlapped_counts_ch)
        overlapped_reads = paired_overlapped_reads_ch.mix(single_overlapped_reads_ch)

        fastp_report_ch = FASTP.out.sample_name.merge(FASTP.out.json)
        decontam_report_ch = DECONTAMINATION_REPORT.out.sample_name.merge(DECONTAMINATION_REPORT.out.decontamination_report)
        report_ch = overlapped_counts.join(fastp_report_ch).join(decontam_report_ch).join(sample.map{tuple(it.meta.id, it)})
        
        QC_REPORT(
            report_ch.map{ it[0] },
            report_ch.map{ it[4].mode },
            report_ch.map{ it[2] },
            report_ch.map{ it[3] },
            report_ch.map{ it[1] }
        )

        FASTQ_TO_FASTA(
            overlapped_reads.map{ it[0] },
            overlapped_reads.map{ it[1] }
        )
        sequence_ch = FASTQ_TO_FASTA.out.sample_name.merge(FASTQ_TO_FASTA.out.sequence)
        QC_STATS(sequence_ch.map{ it[0] }, sequence_ch.map{ it[1] })

    emit:
        merged_reads = overlapped_reads
        sequence = sequence_ch 
        qc_report = QC_REPORT.out.sample_name.merge(QC_REPORT.out.qc_report)
        qc_stats = QC_STATS.out.sample_name.merge(QC_STATS.out.qc_statistics)
        fastp_json = fastp_report_ch
}
