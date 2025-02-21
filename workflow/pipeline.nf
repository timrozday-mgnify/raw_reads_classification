/*
    ~~~~~~~~~~~~~~~~~~
     Steps
    ~~~~~~~~~~~~~~~~~~
*/
include { QC } from '../subworkflows/qc_swf'
include { MAPSEQ_OTU_KRONA } from '../subworkflows/mapseq_otu_krona_swf'
include { CMSEARCH_SUBWF } from '../subworkflows/cmsearch_swf'
include { FETCHTOOL_RAWREADS } from '../modules/fetchtool'
include { MOTUS } from '../modules/motus'
include { MULTIQC } from '../modules/multiqc'
include { FETCH_READS } from '../subworkflows/fetch_reads'

/*
    ~~~~~~~~~~~~~~~~~~
     DBs
    ~~~~~~~~~~~~~~~~~~
*/
include { DOWNLOAD_MOTUS_DB } from '../subworkflows/prepare_dbs'
include { DOWNLOAD_HOST_REFERENCE_GENOME } from '../subworkflows/prepare_dbs'
include { DOWNLOAD_RFAM } from '../subworkflows/prepare_dbs'
include { DOWNLOAD_MAPSEQ_SSU } from '../subworkflows/prepare_dbs'
include { DOWNLOAD_MAPSEQ_LSU } from '../subworkflows/prepare_dbs'

// Import samplesheetToList from nf-schema //
include { samplesheetToList } from 'plugin/nf-schema'

/*
    ~~~~~~~~~~~~~~~~~~
     Run workflow
    ~~~~~~~~~~~~~~~~~~
*/
workflow PIPELINE {
    // Read input samplesheet and validate it using schema_input.json //
    samplesheet = samplesheetToList(params.input, "./assets/schema_input.json") 
    // samplesheet_ch = Channel.fromList(samplesheet)
    // samplesheet_ch.view{ "samplesheet - ${it}" }

    sample2fp_list = []
    samplesheet.each{
        meta, fq1, fq2, fqb, fq1_md5, fq2_md5, fqb_md5 -> 
        if(fq1) {
            sample2fp_list.add([meta.id,fq1,fq1_md5,'reads'])
        }
        if(fq2) {
            sample2fp_list.add([meta.id,fq2,fq2_md5,'reads'])
        }
        if(fqb) {
            sample2fp_list.add([meta.id,fqb,fqb_md5,'barcodes'])
        }
    }
    sizes = [:]
    sample2fp_list.each{
        sample_name, fp, md5, t ->
        if(sizes[sample_name]) {
            sizes[sample_name] += 1
        }else{
            sizes[sample_name] = 1
        }
    }

    fetch_ch = Channel.fromList(sample2fp_list)
    // fetch_ch.view{ "fetch_ch - ${it}"}
    FETCH_READS(fetch_ch)
    // FETCH_READS.out.view{ "FETCH_READS.out - ${it}" }
    
     qc_ch = FETCH_READS.out.map{ k,fp,t -> tuple(groupKey(k,sizes[k]),tuple(fp,t))}.groupTuple() 
     qc_ch = qc_ch.map{ k,fps -> 
         def fps_d = [:]
        fps.sort().each{ fp,t -> 
            if(fps_d[t]) {
                fps_d[t].add(fp)
            }else{
                fps_d[t] = [fp]
            }
        }
        return tuple(k,fps_d)
    }
    qc_ch = qc_ch.filter{ (it[1].reads) && (it[1].reads.size()>0)}.map{ k,fps -> ['meta': ['id': k],'reads': fps,'mode': fps.reads.size()>1 ? 'paired':'single'] }
    // qc_ch.view{ "qc_ch - ${it}" }

    DOWNLOAD_HOST_REFERENCE_GENOME()
    ref_genome_dir = DOWNLOAD_HOST_REFERENCE_GENOME.out.ref_genome_dir
    // ref_genome_dir.view{ "ref_genome_dir - ${it}"}

    QC(
        qc_ch,
        ref_genome_dir,
    )
    // QC.out.merged_reads.view{ "QC.out.merged_reads - ${it}" }

     // mOTUs
    DOWNLOAD_MOTUS_DB()
    motus_db_dir = DOWNLOAD_MOTUS_DB.out.motus_db
    // motus_db_dir.view{ "motus_db_dir - ${it}" }

    MOTUS(QC.out.merged_reads, motus_db_dir)
    // MOTUS.out.motus_result_cleaned.view{ "MOTUS.out.motus_result_cleaned - ${it}" }
    
    DOWNLOAD_RFAM()
    rfam_db_dir = DOWNLOAD_RFAM.out.rfam_db_dir
    rfam_dbs = rfam_db_dir.multiMap{ it ->
        ribo_models: file("${it}/${params.databases.rfam.files.ribosomal_models_file}")
        other_models: file("${it}/${params.databases.rfam.files.other_models_file}")
        ribo_claninfo: file("${it}/${params.databases.rfam.files.ribosomal_claninfo_file}")
        other_claninfo: file("${it}/${params.databases.rfam.files.other_claninfo_file}")
    }
    // rfam_dbs.ribo_models.view{ "rfam_dbs.ribo_models - ${it}" }
    // rfam_dbs.other_models.view{ "rfam_dbs.other_models - ${it}" }
    // rfam_dbs.ribo_claninfo.view{ "rfam_dbs.ribo_claninfo - ${it}" }
    // rfam_dbs.other_claninfo.view{ "rfam_dbs.other_claninfo - ${it}" }

    // CMSEARCH
    CMSEARCH_SUBWF(
        QC.out.sequence.map{ it[0] },
        QC.out.sequence.map{ it[1] },
        rfam_dbs.ribo_models,
        rfam_dbs.ribo_claninfo
    )
    
    DOWNLOAD_MAPSEQ_LSU()
    mapseq_lsu_db_dir = DOWNLOAD_MAPSEQ_LSU.out.mapseq_lsu_db_dir
    // mapseq_lsu_db_dir.view{ "mapseq_lsu_db_dir - ${it}" }
    
    mapseq_lsu_dbs = mapseq_lsu_db_dir.multiMap{ it ->
        otu: file("${it}/${params.databases.silva_lsu.files.otu}")
        fasta: file("${it}/${params.databases.silva_lsu.files.fasta}")
        tax: file("${it}/${params.databases.silva_lsu.files.tax}")
        mscluster: file("${it}/${params.databases.silva_lsu.files.mscluster}")
    }

    MAPSEQ_OTU_KRONA(
        CMSEARCH_SUBWF.out.sample_name,
        CMSEARCH_SUBWF.out.cmsearch_lsu_fasta,
        mapseq_lsu_dbs.otu,
        mapseq_lsu_dbs.fasta,
        mapseq_lsu_dbs.mscluster,
        mapseq_lsu_dbs.tax,
        params.databases.silva_lsu.variables.label
    )
    
    // // MAPSEQ SSU
    // if (CMSEARCH_SUBWF.out.cmsearch_ssu_fasta) {
    //     if (params.ssu_db) {
    //         mapseq_ssu = Channel.fromPath("${params.ssu_db}")
    //     }
    //     else {
    //         DOWNLOAD_MAPSEQ_SSU()
    //         mapseq_ssu = DOWNLOAD_MAPSEQ_SSU.out.mapseq_db_ssu
    //     }
    //     MAPSEQ_OTU_KRONA_SSU(
    //         CMSEARCH_SUBWF.out.cmsearch_ssu_fasta,
    //         mapseq_ssu,
    //         Channel.value(params.ssu_db_otu),
    //         Channel.value(params.ssu_db_fasta),
    //         Channel.value(params.ssu_db_tax),
    //         Channel.value(params.ssu_label)
    //     )
    // }

    // MULTIQC(
    //     QC.out.fastp_json,
    //     MOTUS.out.motus_log
    // )
}
