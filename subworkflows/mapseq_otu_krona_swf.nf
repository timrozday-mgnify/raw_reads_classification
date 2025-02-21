/*
 * Classify with mapseq, convert mapseq2biom, generate krona plots
 */

include { MAPSEQ } from '../modules/mapseq'
include { MAPSEQ2BIOM } from '../modules/mapseq2biom'
include { KRONA } from '../modules/krona'

workflow MAPSEQ_OTU_KRONA {
    take:
        sample_name
        sequence
        otu_ref
        db_fasta
        db_mscluster
        db_tax
        db_label

    main:

        MAPSEQ(
            sample_name,
            sequence,
            db_fasta,
            db_mscluster,
            db_tax,
            db_label
        )

        MAPSEQ2BIOM(
            MAPSEQ.out.sample_name,
            MAPSEQ.out.mapseq_result,
            otu_ref,
            db_label
        )
        
        KRONA(
            MAPSEQ2BIOM.out.sample_name,
            db_label,
            MAPSEQ2BIOM.out.mapseq2biom_txt
        )
        
        output_ch = MAPSEQ.out.sample_name.merge(MAPSEQ.out.mapseq_result).join(MAPSEQ2BIOM.out.sample_name.merge(MAPSEQ2BIOM.out.mapseq2biom_txt))
        
    emit:
        sample_name = output_ch.map{ it[0] }
        mapseq = output_ch.map{ it[1] }
        biom = output_ch.map{ it[2] }
}

