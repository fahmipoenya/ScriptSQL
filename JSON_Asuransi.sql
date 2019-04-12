 
Declare @jsonsimas nvarchar(max)
set @jsonsimas = 
(Select 
--============= QUOTATION ===============
	'007' AS [NBWorkPage.Quotation.GroupPanel], 
	'MBU' AS [NBWorkPage.Quotation.BusinessName], 
	'10138' AS [NBWorkPage.Quotation.BusinessCode], 
	'100000000317' AS [NBWorkPage.Quotation.AccessCode],
--============= POLICY ===============
	format(CI.INS_DT1,'yyyyMMdd') as [NBWorkPage.Policy.StartDateString],
	format(CI.INS_DT2,'yyyyMMdd') as [NBWorkPage.Policy.EndDateString],
	'PT. MITSUI LEASING CAPITAL INDONESIA QQ ' + 
	CASE WHEN  rtrim(ltrim(REPLACE(REPLACE(REPLACE(cl.LESSEE_NM , CHAR(10), ''), CHAR(13), ''), CHAR(9), ''))) 
	=  rtrim(ltrim(REPLACE(REPLACE(REPLACE(cE.BPKB_AN , CHAR(10), ''), CHAR(13), ''), CHAR(9), ''))) THEN
	CL.LESSEE_NM ELSE (CL.LESSEE_NM + ' QQ ' + CE.BPKB_AN) END
	as [NBWorkPage.Policy.QQName],
	CASE WHEN CL.LESSEE_TP = 'PR' THEN 1 ELSE 2 END as [NBWorkPage.Policy.CustomerType],
	CASE WHEN CC.CURR_CODE = 'IDR' THEN '10001'
		WHEN CC.CURR_CODE = 'USD' THEN '10026' END  as [NBWorkPage.Policy.Currency],
	rtrim(ltrim(REPLACE(REPLACE(REPLACE(cl.LESSEE_NM , CHAR(10), ''), CHAR(13), ''), CHAR(9), ''))) as  [NBWorkPage.Policy.TheInsured],
	cc.LEASE_NO as [NBWorkPage.Policy.RefNo],
	''  as [NBWorkPage.Policy.CaseID],
	'1' as [NBWorkPage.Policy.StatusPenerbitan],
--========================== CUSTOMER_C ===========================
--ASMContactPerson
	ISNULL(CL.CONTACT,'') as  [NBWorkPage.Customer_C.ASMContactPerson.pyFullname], 
	CL.Mobile_phone1 as [NBWorkPage.Customer_C.ASMContactPerson.pyMobilePhone], 
	CL.LESSEE_NM as [NBWorkPage.Customer_C.pyCompany], 
	CASE WHEN Lessee_Cat = 'CV' THEN '05' ELSE '04' END as [NBWorkPage.Customer_C.pyTitle], 
	'' as [NBWorkPage.Customer_C.ASMComID],
	CL.NPWP as [NBWorkPage.Customer_C.ASMNPWP],
--ASMDirectorPerson
--========================== ADDRESSLIST ===========================

	( select 
	    case when 	cl.LESSEE_TP = 'PR' then '1' ELSE '2' END as ASMAddressType,
		case when	cl.LESSEE_TP = 'PR' then dbo.[fn_CleanAndTrim](cl.zipcode1,'','','1')  
		else		dbo.[fn_CleanAndTrim](cl.zipcode2,'','','1') end as ASMZipCode,	
		case when	cl.LESSEE_TP = 'PR' then dbo.[fn_CleanAndTrim](cl.ADDRESS1,'','','1') + ', ' + dbo.[fn_CleanAndTrim](cl.CITY1,'','','1')  
		else		dbo.[fn_CleanAndTrim](cl.ADDRESS2,'','','1') + ', ' + dbo.[fn_CleanAndTrim](cl.CITY2,'','','1') end as ASMAddress,	
		( select * from 
		  (select CASE WHEN CL.LESSEE_TP = 'PR' THEN '1' ELSE '5' END as TelfaxType, '' as TelfaxCode,
				  CASE WHEN CL.LESSEE_TP = 'PR' THEN CL.PHONE2 ELSE CL.PHONE1 END as TelfaxNumber  
		  		  union all
 		   select '6' as TelfaxType,null as TelfaxCode,isnull(cl.EMAIL1,'') as TelfaxNumber) N		  		 
		 for JSON path ) as [ASMTelfax]
	  for JSON path )as [NBWorkPage.AddressList],


--========================== VehicleList ===========================
    ( Select    isnull(CE1.CHASIS,'')  as ChassisNumber, isnull(CE1.COLOUR,'')  as ColorName  ,
                isnull(CE1.ENGINE,'')  as EngineNumber, isnull(CE1.POLICENO,ls.DefaultLicensePlate) as LicensePlate, 
                isnull(CE1.TAHUN,'') as ManufactureYear, isnull(cc1.L_AMOUNT,'') as TSI,
                isnull(ut1.TYPE_NM,'') as TypeName, isnull(ub1.BRAND_NM,'')as BrandName,
                CASE WHEN CE1.PURPOSE IN ('01', '02') THEN 'PRIBADI / DINAS' ELSE 'KOMERSIL' END  as [Occupation.OccupationName],
                ( select CD2.YEAR_NO as [Year],
                         CASE WHEN CD2.TLO_AR IN (1,3) THEN 'KERUGIAN TOTAL' 
		                      WHEN CD2.TLO_AR IN (2,4) THEN 'GABUNGAN' ELSE '-' END as [CoverageNote],
                        ( select * from (select 'TJH'as CoverageNote, isnull(CD2.TPL_AMT,0) as TSITJH,NULL as TSI,null AS NumberofPassenger 
                          where CD2.TPL_AMT > 0
						  union all
						  select 'PA Penumpang'as CoverageNote, null as TSITJH, isnull(CD2.SEAT_AMOUNT,0) as TSI  ,isnull(CD2.SEAT,0) AS NumberofPassenger 
						  where CD2.SEAT_AMOUNT > 0
						  union all
                          select 'PA Pengemudi'as CoverageNote, null as TSITJH, isnull(CD2.PA_AMOUNT,0) as TSI  ,NULL AS NumberofPassenger
						  where CD2.PA_AMOUNT > 0
						   )x
                          for JSON path 
                        ) as [AdditionalCoverage]
                  from   clfinsu ci2 INNER JOIN clfinsud cd2 on ci2.ins_pol = cd2.ins_pol
                  where  cc.lease_no = ci2.lease_no  and ci2.flgdel = 0  
                         and ci2.INS_CD in (select ins_cd from umfinscd where ins_co = 'Asuransi Sinar Mas') for JSON path )as [CoverageList]
      from  clfequip ce1 
            inner join clfcont cc1 on cc1.LEASE_NO = ce1.LEASE_NO
            inner join umftype ut1 on ce1.brand = ut1.brand and ce1.type = ut1.type
            inner join umfbrand ub1 on ce1.brand = ub1.BRAND
            
      where ce1.FLGDEL ='0' and ce1.LEASE_NO = cc.lease_no for JSON path) as [NBWorkPage.VehicleList]
   --- UB.BRAND_NM as [NBWorkPage.VehicleList.BrandName],
	---CE.CHASIS as [NBWorkPage.VehicleList.ChassisNumber]

from clfcont cc 
inner join clfless cl on cc.lessee_no = cl.lessee_no
inner join clfequip ce on cc.lease_no = ce.lease_no  
inner join clfinsu ci on cc.lease_no = ci.lease_no and ci.flgdel = 0 and INS_CD in (select ins_cd from umfinscd where ins_co = 'Asuransi Sinar Mas')
LEFT  join SimasJSON_LicensePlate ls on ls.branch_cd = cc.BRANCH_CD
---INNER JOIN clfinsud cd on ci.ins_pol = cd.ins_pol
---inner join umfbrand ub on ce.brand = ub.BRAND
---inner join umftype ut on ce.brand = ut.brand and ce.type = ut.type
---inner join mstpurpose mp on ce.PURPOSE = mp.PURPOSE
where 
 ----cc.execution between '1 feb 2019' and '2 feb 2019' 
 ----AND 
 cc.LEASE_NO='151411241'
 and ce.flgdel = 0
 for JSON path, WITHOUT_ARRAY_WRAPPER 
)

select @jsonsimas as JsonSimas

 