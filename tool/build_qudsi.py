# Builds assets/hadith/qudsi.json (the Hadith Qudsi tab).
# Run from a folder holding ara-bukhari.json, ara-muslim.json and aq.json
# (ara-qudsi.min.json), downloaded from
# https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/<name>.min.json
#   python build_qudsi.py <path to assets/hadith/qudsi.json>
import json,re,sys
out_path=sys.argv[1]
B={x['hadithnumber']:x for x in json.load(open('ara-bukhari.json',encoding='utf-8'))['hadiths']}
M={x['hadithnumber']:x for x in json.load(open('ara-muslim.json',encoding='utf-8'))['hadiths']}
Q=json.load(open('aq.json',encoding='utf-8'))['hadiths']
sets='''b806 b7437 b7438 m451
b846 b1038 b4147 b7503 m231 m232
b1145 m1772
b1363 b1364 b3463 m307
b1904 b7492 b7538 m2704 m2706 m2707 m2708
b2227 b2270
b2348 b7519
b3193 b4482 b4974 b4975
b3244 b4779 b4780 b7498 m7132 m7133 m7134
b3348 b6530 m532 b4741 b7483
b3350 b4769
b4826 b5352 b7491 b7505 m5863 m5864 b6181 m5862 m7528
b4850 b7449 m7172 m7173 m7175
b5653
b6408 m6839
b6424
b6481 b7508 b3481 m6981
b6502
b6549 b7518 m7140
b6557
b7405 b7536 m6805 m6807 m6829 m6830 m6832 m6833 m6952
b7439
b7485
b7501 m334 m335 m336
b7504
b1413
m411
m449
m461
m463
m464
m499
m878 m879
m1432
m2308 m2309
m3996 m3997
m4885
m4923
m6544
m6548
m6556
m6572 m6575
m6681
m6970
m6986
m7475'''.split('\n')
FIX={6544:2565,6981:2756} # standard numbers missing in the data
def num(x):
    if x is M.get(x['hadithnumber']) and x['hadithnumber'] in FIX: return str(FIX[x['hadithnumber']])
    a=x.get('arabicnumber'); v=a if a else x['hadithnumber']
    return str(int(float(v)))
hadiths=[]
for line in sets:
    ids=line.split()
    rep=next((i for i in ids if i[0]=='b'),ids[0])
    src=B if rep[0]=='b' else M
    x=src[int(rep[1:])]
    assert x['text'].strip(), rep
    bn=sorted({num(B[int(i[1:])]) for i in ids if i[0]=='b'},key=float)
    mn=sorted({num(M[int(i[1:])]) for i in ids if i[0]=='m'},key=float)
    parts=[]
    if bn: parts.append('البخاري ('+'، '.join(bn)+')')
    if mn: parts.append('مسلم ('+'، '.join(mn)+')')
    hadiths.append({'text':x['text'].strip()+'<br><br>رواه '+' و'.join(parts),'from':rep})
# the Forty's narrations from other books, with sound chains
for k in [7,9,19,22,26,34,38]:
    hadiths.append({'text':[q for q in Q if q['hadithnumber']==k][0]['text'].strip(),'from':f'qudsi40:{k}'})
data={'metadata':{'name':'الأحاديث القدسية الصحيحة','section':{},'source':'Sahih al-Bukhari, Sahih Muslim and Forty Hadith Qudsi, from fawazahmed0/hadith-api'},
      'hadiths':[{'hadithnumber':i+1,'arabicnumber':i+1,'text':h['text'],'grades':[],'reference':{'book':0,'hadith':i+1},'from':h['from']} for i,h in enumerate(hadiths)]}
json.dump(data,open(out_path,'w',encoding='utf-8'),ensure_ascii=False,indent=0)
print(len(hadiths))
