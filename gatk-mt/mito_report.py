#!/usr/bin/env python3

import argparse
import glob
import os
import pandas as pd
import re
import sys
import vcfpy


def get_args():
    """Get cmdline args"""
    parser = argparse.ArgumentParser(
            description='Annotate Mitochondrial VCFs with GREGoR Data Model')
    parser.add_argument('-p','--participants',required=True,
                        help='Path to participant.tsv exported from AnVIL')
    parser.add_argument('-a','--analytes',required=True,
                        help='Path to analyte.tsv exported from AnVIL')
    parser.add_argument('-d','--aligned_metrics',required=True,
                        help='Path to aligned_dna_short_read.tsv exported from AnVIL')
    parser.add_argument('-c','--coverage',required=True,
                        help='Path to coverage table with coverage metrics generated with samtools coverage')
    parser.add_argument('-i','--input_vcfs',required=True,
                        help='Path to annotated VCF files')
    parser.add_argument('-o','--output',required=True,
                        help='Path of output XLSX file')
    return parser.parse_args()


def get_participant_list(vcf_path):
    vcfs = glob.glob(f"{vcf_path}/*.anno.vcf",recursive=False)
    participant_dict = dict()
    #relation_dict = {
    #        0:'self',
    #        1:'father',
    #        2:'mother',
    #        3:'sibling',
    #        4:'grandparent'
    #        }
    for vcf in glob.glob(f"{vcf_path}/*.anno.vcf",recursive=False):
        pid = os.path.basename(vcf).split('.')[0]
        participant_dict[pid] = dict()
        consent_id = pid.split('_')[0]  # Remove analyte and sequence IDs if present
        family_id = int(consent_id.split('-')[2])
        role = int(consent_id.split('-')[3])
        participant_dict[pid]['family_id'] = family_id
        participant_dict[pid]['proband_relationship'] = role
        participant_dict[pid]['variants'] = parse_vcf_info(vcfpy.Reader.from_path(vcf))
    return participant_dict


def import_data_model_participant(participants_tsv,participant_dict):
    """Get participant age and phenotype descriptions"""
    anvil_participants_df = pd.read_csv(participants_tsv,sep='\t',header=0,keep_default_na=False)
    for pid in participant_dict:
        consent_id = pid.split('_')[0]  # Remove analyte and sequence IDs if present
        participant_row = anvil_participants_df.loc[anvil_participants_df['entity:participant_id']==consent_id]
        if participant_row.empty:  # Placeholders if ID not present in AnVIL
            participant_dict[pid]['sex'] = 'NA'
            participant_dict[pid]['age_at_last_observation'] = 'NA'
            participant_dict[pid]['affected_status'] = 'NA'
            participant_dict[pid]['phenotype_description'] = 'NA'
            participant_dict[pid]['prior_testing'] = 'NA'
        else:
            participant_dict[pid]['sex'] = participant_row['sex'].values[0]
            participant_dict[pid]['age_at_last_observation'] = participant_row['age_at_last_observation'].values[0]
            participant_dict[pid]['affected_status'] = participant_row['affected_status'].values[0]
            participant_dict[pid]['phenotype_description'] = participant_row['phenotype_description'].values[0]
            participant_dict[pid]['prior_testing'] = participant_row['prior_testing'].values[0]
    return participant_dict


def import_data_model_analyte(analytes_tsv,participant_dict):
    """Get participant sample type"""
    uberon_dict = {
            'UBERON:0000178':'blood',
            'UBERON:0000479':'tissue',
            'UBERON:0006956':'buccal_mucosa'
            }
    analytes_df = pd.read_csv(analytes_tsv,sep='\t',header=0,keep_default_na=False)
    # Select only DNA analytes that are not flagged as PacBio or ONT
    analytes_sr_dna_df = analytes_df.loc[(analytes_df['analyte_type']=='DNA')
            & (~analytes_df['entity:analyte_id'].str.endswith('.PB'))
            & (~analytes_df['entity:analyte_id'].str.endswith('.ONT'))][[
            'entity:analyte_id','participant_id','primary_biosample']]
    # For participants with multiple analytes, select the latest one
    for pid in participant_dict:
        if len(pid.split('_')) > 1:
            analyte_id = pid.split('_')[1]
            consent_id = pid.split('_')[0]  # Strip analyte and seq IDs if present
            match = analytes_sr_dna_df.loc[(analytes_sr_dna_df['participant_id']==consent_id)&
                                           (analytes_sr_dna_df['entity:analyte_id']==analyte_id)]
        else:
            match = analytes_sr_dna_df.loc[(analytes_sr_dna_df['participant_id']==pid)]
        if match.empty:
            participant_dict[pid]['primary_biosample'] = 'unknown'
        else:
            participant_dict[pid]['primary_biosample'] = uberon_dict[match['primary_biosample'].values[0]]
    return participant_dict


def import_data_model_coverage(aligned_dna_short_read_tsv,coverage_path,participant_dict):
    """Get participant coverage"""
    aligned_dna_sr_df = pd.read_csv(aligned_dna_short_read_tsv,sep='\t',header=0,keep_default_na=False)
    for pid in participant_dict:
        mean_coverage = aligned_dna_sr_df.loc[aligned_dna_sr_df[
                'experiment_dna_short_read_id']==pid]['mean_coverage']
        if mean_coverage.empty:
            participant_dict[pid]['WGS_coverage'] = 'NA'
        else:
            participant_dict[pid]['WGS_coverage'] = mean_coverage.values[0]
        mt_coverage_df = pd.read_csv(f"{coverage_path}/{pid}.coverage.txt",sep='\t',header=0)
        participant_dict[pid]['MT_coverage'] = mt_coverage_df.loc[
                mt_coverage_df['#rname']=='chrM']['meandepth'].values[0]
    return participant_dict


def parse_vcf_info(reader):
    """Parse variants in VCF files"""
    variant_dict = dict()
    franklin_url = 'https://franklin.genoox.com/clinical-db/variant/snp'
    clinvar_url = 'https://www.ncbi.nlm.nih.gov/clinvar/variation'
    clnrevstat_dict = {
            'practice_guideline':4,
            'reviewed_by_expert_panel':3,
            'criteria_provided,_multiple_submitters,_no_conflicts':2,
            'criteria_provided,_conflicting_classifications':1,
            'criteria_provided,_single_submitter':1,
            'no_assertion_criteria_provided':0,
            'no_classification_provided':0,
            'no_classification_for_the_individual_variant':0
            }
    for variant in reader:
        ecoordinate = f'{variant.CHROM}:{variant.POS}_{variant.REF}>{variant.ALT[0].value}'
        variant_dict[ecoordinate] = dict()
        fcoordinate = re.sub(r'[:_>]','-',ecoordinate)
        franklin_link_e = f'=HYPERLINK("{franklin_url}/{fcoordinate}","{ecoordinate}")'
        variant.INFO = variant.INFO
        af_hom = '.'
        af_het = '.'
        max_hl = '.'
        vep = '.'
        vep_cons = '.'
        vep_gene = '.'
        if 'gnomad.AF_hom' in variant.INFO:
            af_hom = variant.INFO['gnomad.AF_hom']
            af_het = variant.INFO['gnomad.AF_het']
            max_hl = variant.INFO['gnomad.max_hl']
            vep = variant.INFO['gnomad.vep'][0].split('|')
            vep_cons = vep[1]
            vep_gene = vep[3]
        clnid = '.'
        cln_link_e = '.'
        clnsig = '.'
        clnrevs = '.'
        if 'clinvar.ID' in variant.INFO:
            clnid = variant.INFO['clinvar.ID']
            cln_link_e = f'=HYPERLINK("{clinvar_url}/{clnid}","{clnid}")'
            clnsig = variant.INFO['clinvar.CLNSIG'][0]
            clnrevs = clnrevstat_dict[','.join(variant.INFO['clinvar.CLNREVSTAT'])]
        mm_disease = '.'
        if 'mitomap.Disease' in variant.INFO:
            mm_disease =  variant.INFO['mitomap.Disease'][0]
        tApogee_score = '.'
        if 'tApogee.tAPOGEE_score' in variant.INFO:
            tApogee_score = variant.INFO['tApogee.tAPOGEE_score']
        variant_dict[ecoordinate]['franklin_link'] = franklin_link_e
        variant_dict[ecoordinate]['clinvar_link'] = cln_link_e
        variant_dict[ecoordinate]['vep_gene'] = vep_gene
        variant_dict[ecoordinate]['vep_cons'] = vep_cons
        variant_dict[ecoordinate]['af_hom'] = af_hom
        variant_dict[ecoordinate]['af_het'] = af_het
        variant_dict[ecoordinate]['max_hl'] = max_hl
        variant_dict[ecoordinate]['clnsig'] = clnsig
        variant_dict[ecoordinate]['clnrevs'] = clnrevs
        variant_dict[ecoordinate]['mm_disease'] = mm_disease
        variant_dict[ecoordinate]['tApogee_score'] = tApogee_score
        variant_dict[ecoordinate]['FILTER'] = ','.join(variant.FILTER)
        variant_dict[ecoordinate]['VAF'] = variant.calls[0].data.get('AF')[0]
        variant_dict[ecoordinate]['DEPTH'] = variant.calls[0].data.get('DP')
    return variant_dict


def print_table(participants_dict,output_xlsx):
    """Write dataframe to file"""
    out_dfs = dict()
    for pid in participants_dict:
        out_dfs[pid] = pd.DataFrame.from_dict(participants_dict[pid]['variants'],orient='index')
        out_dfs[pid] = out_dfs[pid].reset_index()
        out_dfs[pid] = out_dfs[pid].drop(columns=['index'])
        out_dfs[pid].insert(0,'Role',participants_dict[pid]['proband_relationship'])
        out_dfs[pid].insert(0,'Family_ID',participants_dict[pid]['family_id'])
        out_dfs[pid].insert(0,'#PMGRC_ID',pid)
        out_dfs[pid].insert(len(out_dfs[pid].columns),'Sex',participants_dict[pid]['sex'])
        out_dfs[pid].insert(len(out_dfs[pid].columns),'Age',participants_dict[pid]['age_at_last_observation'])
        out_dfs[pid].insert(len(out_dfs[pid].columns),'Status',participants_dict[pid]['affected_status'])
        out_dfs[pid].insert(len(out_dfs[pid].columns),'Phenotype',participants_dict[pid]['phenotype_description'])
        out_dfs[pid].insert(len(out_dfs[pid].columns),'Prior_Hx',participants_dict[pid]['prior_testing'])
        out_dfs[pid].insert(len(out_dfs[pid].columns),'Sample',participants_dict[pid]['primary_biosample'])
        out_dfs[pid].insert(len(out_dfs[pid].columns),'WGS_cov',participants_dict[pid]['WGS_coverage'])
        out_dfs[pid].insert(len(out_dfs[pid].columns),'MT_cov',participants_dict[pid]['MT_coverage'])
        out_dfs[pid].insert(len(out_dfs[pid].columns),'Notes','')
    output_df = pd.concat(out_dfs.values())
    output_df = output_df.sort_values('Role')
    output_df = output_df.sort_values('Family_ID')
    cohort_df = pd.DataFrame.from_dict(participants_dict,orient='index')
    cohort_df = cohort_df.reset_index()
    cohort_df = cohort_df.sort_values('proband_relationship')
    cohort_df = cohort_df.sort_values('family_id')
    cohort_df = cohort_df.rename(columns={'index':'#PMGRC_ID'})
    cohort_df = cohort_df.drop(columns=['variants'])
    with pd.ExcelWriter(output_xlsx) as writer:
        output_df.to_excel(writer,sheet_name='Variants',index=False,freeze_panes=(1,4))
        cohort_df.to_excel(writer,sheet_name='Cohort',index=False,freeze_panes=(1,3))


if __name__ == '__main__':
    args = get_args()
    participant_dict = get_participant_list(args.input_vcfs)
    import_data_model_participant(args.participants,participant_dict)
    import_data_model_analyte(args.analytes,participant_dict)
    import_data_model_coverage(args.aligned_metrics,args.coverage,participant_dict)
    print_table(participant_dict,args.output)
