// include { FETCHTOOL_RAWREADS } from '../modules/fetchtool'
include { FETCH_URL } from '../modules/fetchurl'

// workflow FETCH_READS {
//     take:
//         reads_accession
//         fetch_config_path

//     main:
//         FETCHTOOL_RAWREADS([reads_accession, reads_accession], fetch_config_path)
//     emit:
//         reads = FETCHTOOL_RAWREADS.reads
// }
workflow FETCH_READS {
    take:
        fetch_ch

    main:
        // check if file is remote
        remote_ch = fetch_ch.filter{ it[1] =~ /^[a-zA-Z]{2,}:\/\// }
        local_ch = fetch_ch.filter{ !(it[1] =~ /^[a-zA-Z]{2,}:\/\//) }.map{ tuple(it[0],it[1],it[3]) }
        cache_path_ch = remote_ch.map{ tuple(it[0],it[1],it[2],it[3],file("${params.reads_cache_path}/${it[0]}/${it[1].tokenize('/').last()}")) }
        download_ch = cache_path_ch.filter{ !it[-1].exists() }.map{ tuple(it[0],it[1],it[2],it[3]) }
        cache_ch = cache_path_ch.filter{ it[-1].exists() }.map{ tuple(it[0],it[-1],it[3]) } 
        downloaded_ch = FETCH_URL(download_ch)
    emit:
        // join downloaded
        local_ch.mix(cache_ch).mix(downloaded_ch)
        
}

        