#!/usr/bin/env python3

import pandas as pd


# Reformat the t-APOGEE quasi-VCF file into a VCF format that GATK VariantAnnotator will accept
apogee_prefix='../ref/chrM/t-APOGEE_2024.0.1'
try:
    apogee_txt_df = pd.read_csv(f'{apogee_prefix}.txt',sep='\t')
except:
    print(f'{apogee_prefix}.txt is missing. Please download it per GitHub readme instructions')

# Rename score columns to remove whitespace
apogee_txt_df.rename(columns={
    'Chr':'#CHROM',
    'Pos':'POS',
    'Ref':'REF',
    'Alt':'ALT',
    't-APOGEE score':'t-APOGEE_score',
    't-APOGEE unbiased score':'t-APOGEE_unbiased_score'
    },inplace=True)
# Fill VCF columns for ID, QUAL, and FILTER with blank values
apogee_txt_df['ID'] = '.'
apogee_txt_df['QUAL'] = '.'
apogee_txt_df['FILTER'] = '.'
apogee_txt_df['INFO'] = 'Gene_symbol=' + apogee_txt_df['Gene_symbol'].astype(str) \
        + ';t-APOGEE_score=' + apogee_txt_df['t-APOGEE_score'].astype(str) \
        + ';t-APOGEE_unbiased_score=' + apogee_txt_df['t-APOGEE_unbiased_score'].astype(str)
apogee_txt_df.drop(['Gene_symbol','t-APOGEE_score','t-APOGEE_unbiased_score'],axis=1,inplace=True)
# reorder columns
apogee_txt_df = apogee_txt_df[['#CHROM','POS','ID','REF','ALT','QUAL','FILTER','INFO']]

with open('./tAPOGEE_header.txt','r') as hdr:
    ta_header = hdr.read()
with open(f'{apogee_prefix}.vcf','w') as vcf:
    vcf.write(ta_header)
apogee_txt_df.to_csv(f'{apogee_prefix}.vcf',sep='\t',mode='a',index=False)
