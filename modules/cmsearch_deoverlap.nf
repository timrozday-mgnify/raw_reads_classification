/*
 * cmsearch deoverlap Perl script
*/

process CMSEARCH_DEOVERLAP {

    label 'cmsearch_deoverlap'
    tag "${sample_name}"
    container 'quay.io/biocontainers/perl:5.22.2.1'

    input:
    val sample_name
    each clan_information
    path cmsearch_matches

    output:
    val sample_name, emit: sample_name
    path "${cmsearch_matches}.deoverlapped", emit: cmsearch_deoverlap

    script:
    """
    cmsearch-deoverlap.pl --clanin ${clan_information} ${cmsearch_matches}
    """
}
