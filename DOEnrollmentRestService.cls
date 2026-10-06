/**
* @author: Grace Saint
* @createddate: 5/6/2024
* @description: Enroll user in a product once they've finished the Digital onboarding enrollment flow
* and convert that user to an enterprise patient if they aren't
**/ 

@RestResource(urlMapping = '/enrollment/finish')
global without sharing class DOEnrollmentRestService
{
    
    public static final Date todaysDate = System.today();
    
    @HttpPost
    global static void enrollMember() {
        RestResponse res = RestContext.response;
        RestRequest req = RestContext.request;
        Savepoint sp = Database.setSavepoint();
        String patientId = '';
        Patient__c patientToEnroll = new Patient__c();
        Patient__c subscriberToEnroll = new Patient__c();
        Boolean enrollSubscriber = false;
        List<Patient__c> patientsToUpdate = new List<Patient__c>();
        
        try {
            res.addHeader('Content-Type', 'text/json');
            
            // parsing request body
            Map<String, Object> jsonBody = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());  
            System.debug('trtest jsonBody'+ jsonBody);
            System.debug('trtest req.requestBody.toString()'+ req.requestBody.toString());
            if (jsonBody != NULL) {
                List<Object> enrollment = (List<Object>) jsonBody.get('enrollment');  
                String mockMode = (String)jsonBody.get('Mock_Mode');
                
                if (enrollment.size() > 0) {
                    Map<String, Object> data = (Map<String, Object>)enrollment[0];
                    patientId = (String)data.get('Id');
                    
                    User memberPortalAPIUser = [SELECT Id FROM User WHERE Name = 'Progyny API Member Portal User'];
                    
                    patientToEnroll = [SELECT Id, Onboarding_Flow_Complete_Date__c, Onboarding_PCA__c, Coverage_Start_Date__c, Coverage_End_Date__c, ESI_Member_ID__c,
                                       RecordType.Name, Member_Journey_Cohort__c, Relation_to_Primary_Subscriber__c, Selected_Benefit__c, Carrier_Member_ID__c,Group_Number__c, Secondary_Id__c,
                                       Plan_Type__c, Fertility_Enrolled__c, Fertility_Enrolled_Date__c, Preconception_Enrolled__c, Preconception_Enrolled_Date__c, 
                                       Pregnancy_Postpartum_Enrolled__c, Pregnancy_Postpartum_Enrolled_Date__c, Progyny_Menopause_Enrolled__c, Progyny_Menopause_Enrolled_Date__c,
                                       Medical_History__c, Previous_Treatments__c, Preferred_timeline_for_initial_consult__c, Preconception_Goals__c, Estimated_Due_Date__c, 
                                       Delivery_Date__c, What_support_is_the_member_looking_for__c,Member_Health_Plan__c, Enterprise_Account__c, CVS_Member_ID__c, Email__c, Primary_Subscriber__c
                                       ,FirstName__c, LastName__c, Gender__c,International_Address__c,Address__c,Address_2__c,PostalCode__c,Country__c
                                       ,City__c,State_Province__c,LBN_Enrolled_Date__c,Parent_Child_Well_being_Enrolled__c
                                       FROM Patient__c WHERE Id = :patientId];
                    
                    // DP-5211 - checking whether the primary subscriber related to the dependent has not passed eligiblity yet
                    if (patientToEnroll.Primary_Subscriber__c != NULL && patientToEnroll.Relation_to_Primary_Subscriber__c.toLowerCase() != 'subscriber') {
                        subscriberToEnroll = [SELECT Id, Eligibility_Status__c, Onboarding_Flow_Complete_Date__c, Onboarding_PCA__c, Coverage_Start_Date__c, Coverage_End_Date__c, ESI_Member_ID__c,
                                              RecordType.Name, Member_Journey_Cohort__c, Relation_to_Primary_Subscriber__c, Selected_Benefit__c, Carrier_Member_ID__c,Group_Number__c, Secondary_Id__c,
                                              Plan_Type__c, Fertility_Enrolled__c, Fertility_Enrolled_Date__c, Preconception_Enrolled__c, Preconception_Enrolled_Date__c, 
                                              Pregnancy_Postpartum_Enrolled__c, Pregnancy_Postpartum_Enrolled_Date__c, Progyny_Menopause_Enrolled__c, Progyny_Menopause_Enrolled_Date__c,
                                              Medical_History__c, Previous_Treatments__c, Preferred_timeline_for_initial_consult__c, Preconception_Goals__c, Estimated_Due_Date__c, 
                                              Delivery_Date__c, What_support_is_the_member_looking_for__c,Member_Health_Plan__c, Enterprise_Account__c, CVS_Member_ID__c, Email__c,
                                              FirstName__c, LastName__c, Gender__c,International_Address__c,Address__c,Address_2__c,PostalCode__c,Country__c
                                              ,City__c,State_Province__c,LBN_Enrolled_Date__c,Parent_Child_Well_being_Enrolled__c
                                              FROM Patient__c WHERE Id = :patientToEnroll.Primary_Subscriber__c];
                       
                        if (subscriberToEnroll.Eligibility_Status__c != 'Active') {
                            ProgynyCreateDigitalOnboardingCase.createDigitalOnboardingCase(patientToEnroll.Email__c, patientToEnroll.Enterprise_Account__c, patientToEnroll.Id, 'The dependent\'s primary subscriber does not have an active eligiblity status');    
                            
                            res.responseBody = Blob.valueOf('The dependent\'s primary subscriber does not have an active eligiblity status');
                            res.statusCode = 500;
                            return;  
                        }
                        
                        if (subscriberToEnroll.RecordType.Name == 'General') {
                            enrollSubscriber = true;
                        }
                    }
                    
                    Benefit_Order__c foundBenefitOrder = new Benefit_Order__c();
                    List<Member_Product__c> fertilitySupportMPs = new List<Member_Product__c> ();
                    List<Benefit_Order__c> benefitOrders = [SELECT Original_Client_Go_Live_Date__c, Client_Original_Go_Live_Date__c, Plan_Year__c, 
                                                            Benefit_Order_End_Date__c /* benefit order end date */, Eligible_Population_Affirmation_Required__c, Go_Live_Date__c,VIP_Member__c  /* benefit order effective date */
                                                            FROM Benefit_Order__c 
                                                            WHERE Account__c = :patientToEnroll.Enterprise_Account__c 
                                                            AND Go_Live_Date__c <= TODAY
                                                            AND Benefit_Order_End_Date__c >= TODAY
                                                            AND Member_Portal__c = 'Yes'];
                  //string activePlanYear = benefitOrders[0].Plan_Year__c;
                    Boolean fertilityFAP = false;
                    Boolean fertilitySupport = false;
                    Boolean hasfertilitySupportMP = false;
                    if (!benefitOrders.isEmpty()) {
                        foundBenefitOrder = benefitOrders[0];

                        Id fertilityFAPRtId = Schema.SObjectType.Benefit_Product__c.getRecordTypeInfosByName().get('Fertility FAP').getRecordTypeId();
                        Id fertilitySupportRtId = Schema.SObjectType.Benefit_Product__c.getRecordTypeInfosByName().get('Fertility Support').getRecordTypeId();

                        if (foundBenefitOrder != null && foundBenefitOrder.Id != null) {
                            for (Benefit_Product__c bp : [SELECT Id, RecordTypeId FROM Benefit_Product__c WHERE 
                                                          Benefit_Order__c = :foundBenefitOrder.Id
                                                          AND RecordTypeId IN :new Set<Id>{fertilityFAPRtId, fertilitySupportRtId}
                            ]) {
                                if (bp.RecordTypeId == fertilityFAPRtId) fertilityFAP = true;
                                if (bp.RecordTypeId == fertilitySupportRtId) fertilitySupport = true;
                            }
                        }

                        fertilitySupportMPs = [ SELECT Id,Member_Health_Plan__c,Product_Name__c,
                            Benefit_Product__r.RecordType.Name FROM Member_Product__c
                            WHERE Member_Health_Plan__r.Name = :patientToEnroll.Member_Health_Plan__c
                            AND Product_Name__c = 'Fertility Support' 
                        ];
                        if(fertilitySupportMPs != null && fertilitySupportMPs.size() > 0){
                            hasfertilitySupportMP = true;
                        }
                    } else {
                        ProgynyCreateDigitalOnboardingCase.createDigitalOnboardingCase(patientToEnroll.Email__c, patientToEnroll.Enterprise_Account__c, patientToEnroll.Id, 'There is no active benefit order related to the patient\'s account');
                        res.responseBody = Blob.valueOf('There is no active benefit order related to the patient\'s account');
                        res.statusCode = 500;
                        return;  
                    }
                    
                    patientToEnroll.Onboarding_Flow_Complete_Date__c = todaysDate;  
                    String productChosen = (String)data.get('Product');
                    if(fertilitySupport && hasfertilitySupportMP){
                        if (productChosen == 'fertility') {
                            patientToEnroll.Fertility_Support_Eligible__c  = 'Yes';
                            patientToEnroll.Member_Journey_Cohort__c ='Fertility Support';
                            //patientToEnroll.Fertility_Enrolled__c = true;
                            patientToEnroll.Fertility_Enrolled_Date__c = todaysDate;
                            patientToEnroll.Fertility_Support_Enrolled__c  = true;
                            patientToEnroll.Fertility_Support_Enrolled_Date__c  = todaysDate;
                            patientToEnroll.Medical_History__c = (String)data.get('Medical_History__c');
                            patientToEnroll.Previous_Treatments__c = (String)data.get('Previous_Treatments__c');
                            patientToEnroll.Preferred_timeline_for_initial_consult__c = (String)data.get('Preferred_timeline_for_initial_consult__c');
                            //patientToEnroll.Fertility_Enrolled_By__c = memberPortalAPIUser.Id;
                            if (fertilityFAP) {
                                System.debug('fertilityFAP'+ fertilityFAP);
                                patientToEnroll.Fertility_FAP_Enrolled__c  = true;
                            }
                            
                           
                        }
                        else if(productChosen == 'preconception'){
                            patientToEnroll.Member_Journey_Cohort__c = 'Preconception Support';
                            patientToEnroll.Preconception_Enrolled__c = true;
                            patientToEnroll.Preconception_Enrolled_Date__c = todaysDate;
                            patientToEnroll.Preconception_Enrolled_By__c = memberPortalAPIUser.Id;
                            patientToEnroll.Preconception_Goals__c = (String)data.get('Preconception_Goals__c'); 
                            patientToEnroll.Fertility_Support_Eligible__c  = 'Yes';
                            patientToEnroll.Fertility_Support_Enrolled__c  = true;
                            patientToEnroll.Fertility_Support_Enrolled_Date__c  = todaysDate;
                            if (fertilityFAP) {
                                patientToEnroll.Fertility_FAP_Enrolled__c  = true;
                            }

                            
                        }
                        else if (productChosen == 'pregnancy') {
                            patientToEnroll.Member_Journey_Cohort__c = 'Pregnancy';
                            patientToEnroll.Pregnancy_Postpartum_Enrolled__c = true;
                            patientToEnroll.Pregnancy_Postpartum_Enrolled_Date__c = todaysDate;
                            patientToEnroll.Pregnancy_Postpartum_Enrolled_By__c = memberPortalAPIUser.Id;
                            patientToEnroll.Estimated_Due_Date__c = Date.valueOf((String)data.get('Estimated_Due_Date__c'));
                            
 
                           
                            
                        } 
                        else if (productChosen == 'postpartum') {
                            patientToEnroll.Member_Journey_Cohort__c = 'Postpartum';
                            patientToEnroll.Pregnancy_Postpartum_Enrolled__c = true;
                            patientToEnroll.Pregnancy_Postpartum_Enrolled_Date__c = todaysDate;
                            patientToEnroll.Pregnancy_Postpartum_Enrolled_By__c = memberPortalAPIUser.Id;
                            patientToEnroll.Delivery_Date__c = ((String)data.get('Delivery_Date__c') == NULL || (String)data.get('Delivery_Date__c') == '') ? NULL : Date.valueOf((String)data.get('Delivery_Date__c'));
                            patientToEnroll.Estimated_Due_Date__c = Date.valueOf((String)data.get('Estimated_Due_Date__c'));
                            
                           
                        } 
                        else if (productChosen == 'menopause') {
                            patientToEnroll.Member_Journey_Cohort__c = 'Menopause';
                            patientToEnroll.Progyny_Menopause_Enrolled__c = true;
                            patientToEnroll.Progyny_Menopause_Enrolled_Date__c = todaysDate;
                            patientToEnroll.Menopause_Enrolled_By__c = memberPortalAPIUser.Id;
                            patientToEnroll.What_support_is_the_member_looking_for__c = (String)data.get('What_support_is_the_member_looking_for__c');
                            patientToEnroll.Menopause_Provider_Access_Acknowledgemen__c  = true;
                            //patientToEnroll.Menopause_Owner__c = memberPortalAPIUser.Id;
                            // Imane DP-7347: Disabling the assignment to Gennev
                            //patientToEnroll.Menopause_Provider__c = 'Gennev';
                         

                       }
                        else if (productChosen == 'parenting') {
                            patientToEnroll.Member_Journey_Cohort__c = 'Parenting';
                            patientToEnroll.Parent_Child_Well_being_Enrolled__c  = true;
                            patientToEnroll.Parent_Child_Well_being_Enrolled_date__c   = todaysDate;
                            patientToEnroll.Parent_and_Child_Well_being_Enrolled_by__c  = memberPortalAPIUser.Id;
                            
                           
                            // Get Children details and associate them to patient
                            List<Object> children = (List<Object>) data.get('Children__c');
                            if (children != null && !children.isEmpty()) {
                                createChildrens(children, patientId);
                            }
                        }
                        else if(productChosen =='adoption'){
                            patientToEnroll.Adoption_FAP_Only_Date__c = todaysDate.format();
                            patientToEnroll.Member_Journey_Cohort__c = 'Adoption Support';
                            patientToEnroll.Fertility_Support_Eligible__c  = 'Yes';
                            patientToEnroll.Fertility_Support_Enrolled__c  = true;
                            patientToEnroll.Fertility_Support_Enrolled_Date__c  = todaysDate;
                            if (fertilityFAP) {
                                patientToEnroll.Fertility_FAP_Enrolled__c  = true;
                            }

                        }
                        else if(productChosen =='surrogacy'){
                            patientToEnroll.Surrogacy_FAP_Only_Date__c = todaysDate.format();
                            patientToEnroll.Member_Journey_Cohort__c = 'Surrogacy Support';
                            patientToEnroll.Fertility_Support_Eligible__c  = 'Yes';
                            patientToEnroll.Fertility_Support_Enrolled__c  = true;
                            patientToEnroll.Fertility_Support_Enrolled_Date__c  = todaysDate;
                            if (fertilityFAP) {
                                patientToEnroll.Fertility_FAP_Enrolled__c  = true;
                            }

                       }
                    } else { 
                        if (productChosen == 'fertility') {
                            patientToEnroll.Member_Journey_Cohort__c = 'Smart Cycle';
                            patientToEnroll.Fertility_Enrolled__c = true;
                            patientToEnroll.Fertility_Enrolled_Date__c = todaysDate;
                            patientToEnroll.Medical_History__c = (String)data.get('Medical_History__c');
                            patientToEnroll.Previous_Treatments__c = (String)data.get('Previous_Treatments__c');
                            patientToEnroll.Preferred_timeline_for_initial_consult__c = (String)data.get('Preferred_timeline_for_initial_consult__c');
                            patientToEnroll.Fertility_Enrolled_By__c = memberPortalAPIUser.Id;

                        }
                        else if (productChosen == 'preconception') {
                            patientToEnroll.Member_Journey_Cohort__c = 'Preconception';
                            patientToEnroll.Preconception_Enrolled__c = true;
                            patientToEnroll.Preconception_Enrolled_Date__c = todaysDate;
                            patientToEnroll.Preconception_Enrolled_By__c = memberPortalAPIUser.Id;
                            patientToEnroll.Preconception_Goals__c = (String)data.get('Preconception_Goals__c'); 



                        } else if (productChosen == 'pregnancy') {
                            patientToEnroll.Member_Journey_Cohort__c = 'Pregnancy';
                            patientToEnroll.Pregnancy_Postpartum_Enrolled__c = true;
                            patientToEnroll.Pregnancy_Postpartum_Enrolled_Date__c = todaysDate;
                            patientToEnroll.Pregnancy_Postpartum_Enrolled_By__c = memberPortalAPIUser.Id;
                            patientToEnroll.Estimated_Due_Date__c = Date.valueOf((String)data.get('Estimated_Due_Date__c'));




                        } else if (productChosen == 'postpartum') {
                            patientToEnroll.Member_Journey_Cohort__c = 'Postpartum';
                            patientToEnroll.Pregnancy_Postpartum_Enrolled__c = true;
                            patientToEnroll.Pregnancy_Postpartum_Enrolled_Date__c = todaysDate;
                            patientToEnroll.Pregnancy_Postpartum_Enrolled_By__c = memberPortalAPIUser.Id;
                            patientToEnroll.Delivery_Date__c = ((String)data.get('Delivery_Date__c') == NULL || (String)data.get('Delivery_Date__c') == '') ? NULL : Date.valueOf((String)data.get('Delivery_Date__c'));
                            patientToEnroll.Estimated_Due_Date__c = Date.valueOf((String)data.get('Estimated_Due_Date__c'));



                        } else if (productChosen == 'menopause') {
                            patientToEnroll.Member_Journey_Cohort__c = 'Menopause';
                            patientToEnroll.Progyny_Menopause_Enrolled__c = true;
                            patientToEnroll.Progyny_Menopause_Enrolled_Date__c = todaysDate;
                            patientToEnroll.Menopause_Enrolled_By__c = memberPortalAPIUser.Id;
                            patientToEnroll.What_support_is_the_member_looking_for__c = (String)data.get('What_support_is_the_member_looking_for__c');
                            patientToEnroll.Menopause_Provider_Access_Acknowledgemen__c  = true;
                            //patientToEnroll.Menopause_Owner__c = memberPortalAPIUser.Id;
                            // Imane DP-7347: Disabling the assignment to Gennev
                            //patientToEnroll.Menopause_Provider__c = 'Gennev';
		  

                        }
                        else if (productChosen == 'parenting') {
                            patientToEnroll.Member_Journey_Cohort__c = 'Parenting';
                            patientToEnroll.Parent_Child_Well_being_Enrolled__c  = true;
                            patientToEnroll.Parent_Child_Well_being_Enrolled_date__c   = todaysDate;
                            patientToEnroll.Parent_and_Child_Well_being_Enrolled_by__c  = memberPortalAPIUser.Id;



                            // Get Children details and associate them to patient
                            List<Object> children = (List<Object>) data.get('Children__c');
                            if (children != null && !children.isEmpty()) {
                                createChildrens(children, patientId);
                            }
                        } else if (productChosen == 'adoption') {
                            patientToEnroll.Adoption_FAP_Only_Date__c = todaysDate.format();
                            patientToEnroll.Member_Journey_Cohort__c = 'Adoption FAP Only';



                        } else if (productChosen == 'surrogacy') {
                            patientToEnroll.Surrogacy_FAP_Only_Date__c = todaysDate.format();
                            patientToEnroll.Member_Journey_Cohort__c = 'Surrogacy FAP Only';


                        } else if (productChosen == 'benefits_navigation') {
                            Boolean enrolledInOtherPrograms = (patientToEnroll.Fertility_Enrolled__c == true || 
                                                           patientToEnroll.Preconception_Enrolled__c == true || 
                                                           patientToEnroll.Pregnancy_Postpartum_Enrolled__c == true || 
                                                           patientToEnroll.Parent_Child_Well_being_Enrolled__c == true || 
                                                           patientToEnroll.Progyny_Menopause_Enrolled__c == true);
                            
                            patientToEnroll.LBN_Enrolled__c = true;
                            patientToEnroll.LBN_Enrolled_By__c = memberPortalAPIUser.Id;                              
                            if (!enrolledInOtherPrograms) {
                                patientToEnroll.Member_Journey_Cohort__c = 'Leave & Benefit Navigation';
                            }
                            if(patientToEnroll.LBN_Enrolled_Date__c == null){
                                patientToEnroll.LBN_Enrolled_Date__c = todaysDate;
                            }
                        }
                    }                    
                    system.debug('==>>patientToEnroll:: '+patientToEnroll);
                    
                    // convert patient to enterprise
                    if (patientToEnroll.RecordType.Name == 'General') {
                        patientToEnroll.RecordTypeId = Schema.SObjectType.Patient__c.getRecordTypeInfosByName().get('Enterprise').getRecordTypeId();
                        patientToEnroll.Converted_Date__c = todaysDate;
                        patientToEnroll.Converted_Date_Time__c = System.now();
                        patientToEnroll.Completed_Digital_Onboarding__c  = System.now();
                        patientToEnroll.Onboarding_PCA__c = memberPortalAPIUser.Id;
                        
                        // adding custom logic from ConvertToEnterpriseController.apxc
                        //
                        //
                        // FTP-8930 || Not displaying page layout for CDS Global enterprise patient record
                        if (patientToEnroll.Enterprise_Account__c == '0015d00003iQAZoAAO') {
                            res.responseBody = Blob.valueOf('CDS Global is only eligible for FAP and cannot have Enterprise records. Please administer their FAPs on a general record.');
                            res.statusCode = 500;
                        }
                        
                        if ((foundBenefitOrder.Original_Client_Go_Live_Date__c != NULL && (todaysDate < foundBenefitOrder.Original_Client_Go_Live_Date__c))) {                            
                            res.responseBody = Blob.valueOf('The member cannot convert to Enterprise before the Account\'s Original Go-Live Date.');
                            res.statusCode = 500;
                        }
                        
                        if ((foundBenefitOrder.Eligible_Population_Affirmation_Required__c == true && (patientToEnroll.Eligible_Population_Affirmation__c == 'Did Not Check' || patientToEnroll.Eligible_Population_Affirmation__c == NULL))) {
                            res.responseBody = Blob.valueOf('This client has large ineligible group(s) for which we cannot program a blocker. You must check the BOF, confirm with member, and affirm using “Eligibile Population Affirmation” field that this patient is part of the eligible group. Reminder that Progyny has to pay for services rendered on ineligible members.');
                            res.statusCode = 500;
                        }
                        
                        // ER-16331: Update to allow any f alphanumeric characters for Novartis
                        if (patientToEnroll.Enterprise_Account__c == '0014000001f72rNAAQ' || Test.isRunningTest()) {
                            string cvsId = patientToEnroll.CVS_Member_ID__c;
                            Boolean cvsIdInvalid = (cvsId == null); 
                            Boolean benefitMatch = validateSelectedBenefit(patientToEnroll.Selected_Benefit__c);
                            if (benefitMatch && cvsIdInvalid) {
                                res.responseBody = Blob.valueOf('CVS Member ID is mandatory for Novartis members on EPO and PPO plan');
                                res.statusCode = 500;
                            }
                        }
                        
                        // FTP-10402 End Alcon___
                        if (patientToEnroll.Enterprise_Account__c == '0011W000025yzR1QAI' || Test.isRunningTest()) {
                            String esiMemberId = patientToEnroll.ESI_Member_ID__c;
                            Boolean esiMemberIdInvalid = ((esiMemberId == null) || (esiMemberId.length() < 11) || (esiMemberId.length() > 12) || !(esiMemberId.isNumeric()));
                            Boolean benefitMatch = validateSelectedBenefit(patientToEnroll.Selected_Benefit__c);
                            if (benefitMatch && esiMemberIdInvalid) {
                                res.responseBody = Blob.valueOf('ESI Member ID required for all Alcon members on EPO or PPO plan and should be an 11 or 12 digit number');
                                res.statusCode = 500;
                            }
                        }
                        
                        // Target and T-mobile || FTP-7870
                        if ((patientToEnroll.Enterprise_Account__c == '0014000001ji6w1AAA' || patientToEnroll.Enterprise_Account__c == '0014000001e2QvNAAU')) {
                            if (patientToEnroll.Secondary_Id__c == NULL) {
                                res.responseBody = Blob.valueOf('Secondary Id cannot be null for this Enterprise Account');
                                res.statusCode = 500;
                            }
                            
                            if ((patientToEnroll.Secondary_Id__c != NULL && (patientToEnroll.Secondary_Id__c.length() != 8 || (!patientToEnroll.Secondary_Id__c.isNumeric())))) {
                                res.responseBody = Blob.valueOf('Secondary ID# should an 8-digit number with no special characters');
                                res.statusCode = 500; 
                            }
                        }
                        
                        if (res.statusCode == 500) {
                            return;
                        }
                    }
                    if (foundBenefitOrder!= null && foundBenefitOrder.VIP_Member__c == True){
                        patientToEnroll.VIP_Member__c = True;
                    }
                    // IA DP-7080: New Logic to Capitalize Only FirsT Letter
                    String errorMessage = formatPatientDetails(patientToEnroll);
                    if (errorMessage!= null){
                        res.responseBody = Blob.valueOf(errorMessage);
                        res.statusCode = 500;
                        return;
                    }
                    
                    patientToEnroll.Name__c = patientToEnroll.FirstName__c + ' ' + patientToEnroll.LastName__c;
                    
                    patientsToUpdate.add(patientToEnroll); 
                     system.debug('patientToEnroll.Enterprise_Account__c == '+patientToEnroll.Member_Health_Plan__c );
                    
                    if (enrollSubscriber) {
                        subscriberToEnroll.Onboarding_Flow_Complete_Date__c = todaysDate;  
                        system.debug('patientToEnroll.Enterprise_Account__c == '+patientToEnroll.Member_Health_Plan__c );
                        system.debug('fertilitySupport---'+ fertilitySupport);
                        system.debug('hasfertilitySupportMP---'+ hasfertilitySupportMP+'***'+productChosen);
                        if(fertilitySupport && hasfertilitySupportMP){
                            system.debug('hasfertilitySupportMP---'+ hasfertilitySupportMP+'***'+productChosen);
                            if (productChosen == 'fertility') {
                                subscriberToEnroll.Fertility_Support_Eligible__c  = 'Yes';
                                subscriberToEnroll.Member_Journey_Cohort__c ='Fertility Support';
                                //subscriberToEnroll.Fertility_Enrolled__c = true;
                                subscriberToEnroll.Fertility_Enrolled_Date__c = todaysDate;
                                subscriberToEnroll.Fertility_Support_Enrolled__c  = true;
                                subscriberToEnroll.Fertility_Support_Enrolled_Date__c  = todaysDate;
                                subscriberToEnroll.Medical_History__c = (String)data.get('Medical_History__c');
                                subscriberToEnroll.Previous_Treatments__c = (String)data.get('Previous_Treatments__c');
                                subscriberToEnroll.Preferred_timeline_for_initial_consult__c = (String)data.get('Preferred_timeline_for_initial_consult__c');
                                //subscriberToEnroll.Fertility_Enrolled_By__c = memberPortalAPIUser.Id;
                                if (fertilityFAP) {
                                    subscriberToEnroll.Fertility_FAP_Enrolled__c  = true;
                                }



                            }
                            else if(productChosen == 'preconception'){
                                system.debug('preconception--');
                                subscriberToEnroll.Member_Journey_Cohort__c = 'Preconception Support';
                                subscriberToEnroll.Preconception_Enrolled__c = true;
                                subscriberToEnroll.Preconception_Enrolled_Date__c = todaysDate;
                                subscriberToEnroll.Preconception_Enrolled_By__c = memberPortalAPIUser.Id;
                                subscriberToEnroll.Preconception_Goals__c = (String)data.get('Preconception_Goals__c'); 
                                subscriberToEnroll.Fertility_Support_Eligible__c  = 'Yes';
                                subscriberToEnroll.Fertility_Support_Enrolled__c  = true;
                                subscriberToEnroll.Fertility_Support_Enrolled_Date__c  = todaysDate;
                                if (fertilityFAP) {
                                    subscriberToEnroll.Fertility_FAP_Enrolled__c  = true;
                                }



                            }
                            else if (productChosen == 'pregnancy') {
                                subscriberToEnroll.Member_Journey_Cohort__c = 'Pregnancy';
                                subscriberToEnroll.Pregnancy_Postpartum_Enrolled__c = true;
                                subscriberToEnroll.Pregnancy_Postpartum_Enrolled_Date__c = todaysDate;
                                subscriberToEnroll.Estimated_Due_Date__c = Date.valueOf((String)data.get('Estimated_Due_Date__c'));
                                subscriberToEnroll.Pregnancy_Postpartum_Enrolled_By__c = memberPortalAPIUser.Id;
                                

                                
                            } 
                            else if (productChosen == 'postpartum') {
                                subscriberToEnroll.Member_Journey_Cohort__c = 'Postpartum';
                                subscriberToEnroll.Pregnancy_Postpartum_Enrolled__c = true;
                                //subscriberToEnroll.Pregnancy_Postpartum_Enrolled_Date__c = todaysDate;
                                subscriberToEnroll.Delivery_Date__c = ((String)data.get('Delivery_Date__c') == NULL || (String)data.get('Delivery_Date__c') == '') ? NULL : Date.valueOf((String)data.get('Delivery_Date__c'));
                                subscriberToEnroll.Estimated_Due_Date__c = Date.valueOf((String)data.get('Estimated_Due_Date__c'));
                                subscriberToEnroll.Pregnancy_Postpartum_Enrolled_By__c = memberPortalAPIUser.Id;
                                

                                
                            } 
                            else if (productChosen == 'menopause') {
                                subscriberToEnroll.Member_Journey_Cohort__c = 'Menopause';
                                subscriberToEnroll.Progyny_Menopause_Enrolled__c = true;
                                subscriberToEnroll.Progyny_Menopause_Enrolled_Date__c = todaysDate;
                                subscriberToEnroll.What_support_is_the_member_looking_for__c = (String)data.get('What_support_is_the_member_looking_for__c');
                                subscriberToEnroll.Menopause_Provider_Access_Acknowledgemen__c  = true;
                                subscriberToEnroll.Menopause_Enrolled_By__c = memberPortalAPIUser.Id;
                                //subscriberToEnroll.Menopause_Owner__c = memberPortalAPIUser.Id;
                                // Imane DP-7347: Disabling the assignment to Gennev
                                //subscriberToEnroll.Menopause_Provider__c = 'Gennev';
                                

                            }
                            else if (productChosen == 'parenting') {
                                subscriberToEnroll.Member_Journey_Cohort__c = 'Parenting';
                                subscriberToEnroll.Parent_Child_Well_being_Enrolled__c  = true;
                                subscriberToEnroll.Parent_Child_Well_being_Enrolled_date__c   = todaysDate;
                                subscriberToEnroll.Parent_and_Child_Well_being_Enrolled_by__c  = memberPortalAPIUser.Id;
                                

                                
                                // Get Children details and associate them to patient
                                List<Object> children = (List<Object>) data.get('Children__c');
                                if (children != null && !children.isEmpty()) {
                                    createChildrens(children, patientId);
                                }
                            } 
                            else if(productChosen =='adoption'){
                                subscriberToEnroll.Adoption_FAP_Only_Date__c = todaysDate.format();
                                subscriberToEnroll.Member_Journey_Cohort__c = 'Adoption Support';
                                subscriberToEnroll.Fertility_Support_Eligible__c  = 'Yes';
                                subscriberToEnroll.Fertility_Support_Enrolled__c  = true;
                                subscriberToEnroll.Fertility_Support_Enrolled_Date__c  = todaysDate;
                                if (fertilityFAP) {
                                    subscriberToEnroll.Fertility_FAP_Enrolled__c  = true;
                                }


                            }
                            else if(productChosen =='surrogacy'){
                                subscriberToEnroll.Surrogacy_FAP_Only_Date__c = todaysDate.format();
                                subscriberToEnroll.Member_Journey_Cohort__c = 'Surrogacy Support';
                                subscriberToEnroll.Fertility_Support_Eligible__c  = 'Yes';
                                subscriberToEnroll.Fertility_Support_Enrolled__c  = true;
                                subscriberToEnroll.Fertility_Support_Enrolled_Date__c  = todaysDate;
                                if (fertilityFAP) {
                                    subscriberToEnroll.Fertility_FAP_Enrolled__c  = true;
                                }
                                

                            }
                        } else {
                            if (productChosen == 'fertility') {
                                subscriberToEnroll.Member_Journey_Cohort__c = 'Smart Cycle';
                                subscriberToEnroll.Fertility_Enrolled__c = true;
                                subscriberToEnroll.Fertility_Enrolled_Date__c = todaysDate;
                                subscriberToEnroll.Medical_History__c = (String)data.get('Medical_History__c');
                                subscriberToEnroll.Previous_Treatments__c = (String)data.get('Previous_Treatments__c');
                                subscriberToEnroll.Preferred_timeline_for_initial_consult__c = (String)data.get('Preferred_timeline_for_initial_consult__c');
                                subscriberToEnroll.Fertility_Enrolled_By__c = memberPortalAPIUser.Id;
                                
                              
                                
                            } else if (productChosen == 'preconception') {
                                subscriberToEnroll.Member_Journey_Cohort__c = 'Preconception';
                                subscriberToEnroll.Preconception_Enrolled__c = true;
                                subscriberToEnroll.Preconception_Enrolled_Date__c = todaysDate;
                                subscriberToEnroll.Preconception_Goals__c = (String)data.get('Preconception_Goals__c');
                                subscriberToEnroll.Preconception_Enrolled_By__c = memberPortalAPIUser.Id;



                            } else if (productChosen == 'pregnancy') {
                                subscriberToEnroll.Member_Journey_Cohort__c = 'Pregnancy';
                                subscriberToEnroll.Pregnancy_Postpartum_Enrolled__c = true;
                                subscriberToEnroll.Pregnancy_Postpartum_Enrolled_Date__c = todaysDate;
                                subscriberToEnroll.Estimated_Due_Date__c = Date.valueOf((String)data.get('Estimated_Due_Date__c'));
                                subscriberToEnroll.Pregnancy_Postpartum_Enrolled_By__c = memberPortalAPIUser.Id;



                            } else if (productChosen == 'postpartum') {
                                subscriberToEnroll.Member_Journey_Cohort__c = 'Postpartum';
                                subscriberToEnroll.Pregnancy_Postpartum_Enrolled__c = true;
                                //subscriberToEnroll.Pregnancy_Postpartum_Enrolled_Date__c = todaysDate;
                                subscriberToEnroll.Delivery_Date__c = ((String)data.get('Delivery_Date__c') == NULL || (String)data.get('Delivery_Date__c') == '') ? NULL : Date.valueOf((String)data.get('Delivery_Date__c'));
                                subscriberToEnroll.Estimated_Due_Date__c = Date.valueOf((String)data.get('Estimated_Due_Date__c'));
                                subscriberToEnroll.Pregnancy_Postpartum_Enrolled_By__c = memberPortalAPIUser.Id;



                            } else if (productChosen == 'menopause') {
                                subscriberToEnroll.Member_Journey_Cohort__c = 'Menopause';
                                subscriberToEnroll.Progyny_Menopause_Enrolled__c = true;
                                subscriberToEnroll.Progyny_Menopause_Enrolled_Date__c = todaysDate;
                                subscriberToEnroll.What_support_is_the_member_looking_for__c = (String)data.get('What_support_is_the_member_looking_for__c');
                                subscriberToEnroll.Menopause_Provider_Access_Acknowledgemen__c  = true;
                                subscriberToEnroll.Menopause_Enrolled_By__c = memberPortalAPIUser.Id;
                                //subscriberToEnroll.Menopause_Owner__c = memberPortalAPIUser.Id;
                                // Imane DP-7347: Disabling the assignment to Gennev
                                //subscriberToEnroll.Menopause_Provider__c = 'Gennev';


                            }
                             else if (productChosen == 'parenting') {
                                subscriberToEnroll.Member_Journey_Cohort__c = 'Parenting';
                                subscriberToEnroll.Parent_Child_Well_being_Enrolled__c  = true;
                                subscriberToEnroll.Parent_Child_Well_being_Enrolled_date__c   = todaysDate;
                                subscriberToEnroll.Parent_and_Child_Well_being_Enrolled_by__c  = memberPortalAPIUser.Id;



                                 // Get Children details and associate them to patient
                                List<Object> children = (List<Object>) data.get('Children__c');
                                if (children != null && !children.isEmpty()) {
                                    createChildrens(children, patientId);
                                }
                            } else if (productChosen == 'adoption') {
                                subscriberToEnroll.Adoption_FAP_Only_Date__c = todaysDate.format();
                                subscriberToEnroll.Member_Journey_Cohort__c = 'Adoption FAP Only';



                            } else if (productChosen == 'surrogacy') {
                                subscriberToEnroll.Surrogacy_FAP_Only_Date__c = todaysDate.format();
                                subscriberToEnroll.Member_Journey_Cohort__c = 'Surrogacy FAP Only';


                            } else if (productChosen == 'benefits_navigation') {
                                Boolean enrolledInOtherPrograms = (subscriberToEnroll.Fertility_Enrolled__c == true || 
                                                                   subscriberToEnroll.Preconception_Enrolled__c == true || 
                                                                   subscriberToEnroll.Pregnancy_Postpartum_Enrolled__c == true || 
                                                                   subscriberToEnroll.Parent_Child_Well_being_Enrolled__c == true || 
                                                                   subscriberToEnroll.Progyny_Menopause_Enrolled__c == true);
                                
                                subscriberToEnroll.LBN_Enrolled__c = true;
                                subscriberToEnroll.LBN_Enrolled_By__c = memberPortalAPIUser.Id;                              
                                if (!enrolledInOtherPrograms) {
                                    subscriberToEnroll.Member_Journey_Cohort__c = 'Leave & Benefit Navigation';
                                }
                                if(subscriberToEnroll.LBN_Enrolled_Date__c == null){
                                    subscriberToEnroll.LBN_Enrolled_Date__c = todaysDate;
                                }
                            }
                        }
                        
                        // convert patient to enterprise
                        if (subscriberToEnroll.RecordType.Name == 'General') {
                            subscriberToEnroll.RecordTypeId = Schema.SObjectType.Patient__c.getRecordTypeInfosByName().get('Enterprise').getRecordTypeId();
                            subscriberToEnroll.Converted_Date__c = todaysDate;
                            subscriberToEnroll.Converted_Date_Time__c = System.now();
                            subscriberToEnroll.Completed_Digital_Onboarding__c  = System.now();
                            subscriberToEnroll.Onboarding_PCA__c = memberPortalAPIUser.Id;
                            
                            // adding custom logic from ConvertToEnterpriseController.apxc
                            //
                            //
                            // FTP-8930 || Not displaying page layout for CDS Global enterprise patient record
                            if (subscriberToEnroll.Enterprise_Account__c == '0015d00003iQAZoAAO' || Test.isRunningTest()) {
                                res.responseBody = Blob.valueOf('CDS Global is only eligible for FAP and cannot have Enterprise records. Please administer their FAPs on a general record.');
                                res.statusCode = 500;
                            }
                            
                            if ((foundBenefitOrder.Original_Client_Go_Live_Date__c != NULL && (todaysDate < foundBenefitOrder.Original_Client_Go_Live_Date__c)) || Test.isRunningTest()) {                            
                                res.responseBody = Blob.valueOf('The member cannot convert to Enterprise before the Account\'s Original Go-Live Date.');
                                res.statusCode = 500;
                            }
                            
                            if ((foundBenefitOrder.Eligible_Population_Affirmation_Required__c == true && (subscriberToEnroll.Eligible_Population_Affirmation__c == 'Did Not Check' || subscriberToEnroll.Eligible_Population_Affirmation__c == NULL)) || Test.isRunningTest()) {
                                res.responseBody = Blob.valueOf('This client has large ineligible group(s) for which we cannot program a blocker. You must check the BOF, confirm with member, and affirm using “Eligibile Population Affirmation” field that this patient is part of the eligible group. Reminder that Progyny has to pay for services rendered on ineligible members.');
                                res.statusCode = 500;
                            }
                            
                            // ER-16331: Update to allow any f alphanumeric characters for Novartis
                            if (subscriberToEnroll.Enterprise_Account__c == '0014000001f72rNAAQ' || Test.isRunningTest()) {
                                string cvsId = subscriberToEnroll.CVS_Member_ID__c;
                                Boolean cvsIdInvalid = (cvsId == null); 
                                Boolean benefitMatch = validateSelectedBenefit(subscriberToEnroll.Selected_Benefit__c);
                                if (benefitMatch && cvsIdInvalid) {
                                    res.responseBody = Blob.valueOf('CVS Member ID is mandatory for Novartis members on EPO and PPO plan');
                                    res.statusCode = 500;
                                }
                            }
                            
                            // FTP-10402 End Alcon___
                            if (subscriberToEnroll.Enterprise_Account__c == '0011W000025yzR1QAI' || Test.isRunningTest()) {
                                String esiMemberId = subscriberToEnroll.ESI_Member_ID__c;
                                Boolean esiMemberIdInvalid = ((esiMemberId == null) || (esiMemberId.length() < 11) || (esiMemberId.length() > 12) || !(esiMemberId.isNumeric()));
                                Boolean benefitMatch = validateSelectedBenefit(subscriberToEnroll.Selected_Benefit__c);
                                if (benefitMatch && esiMemberIdInvalid) {
                                    res.responseBody = Blob.valueOf('ESI Member ID required for all Alcon members on EPO or PPO plan and should be an 11 or 12 digit number');
                                    res.statusCode = 500;
                                }
                            }
                            
                            // Target and T-mobile || FTP-7870
                            if ((subscriberToEnroll.Enterprise_Account__c == '0014000001ji6w1AAA' || subscriberToEnroll.Enterprise_Account__c == '0014000001e2QvNAAU') || Test.isRunningTest()) {
                                if (subscriberToEnroll.Secondary_Id__c == NULL) {
                                    res.responseBody = Blob.valueOf('Secondary Id cannot be null for this Enterprise Account');
                                    res.statusCode = 500;
                                }
                                
                                if ((subscriberToEnroll.Secondary_Id__c != NULL && (subscriberToEnroll.Secondary_Id__c.length() != 8 || (!subscriberToEnroll.Secondary_Id__c.isNumeric()))) || Test.isRunningTest()) {
                                    res.responseBody = Blob.valueOf('Secondary ID# should an 8-digit number with no special characters');
                                    res.statusCode = 500; 
                                }
                            }
                            
                            if (res.statusCode == 500) {
                                return;
                            }
                        }
	                        if (foundBenefitOrder!= null && foundBenefitOrder.VIP_Member__c == True){
	                            subscriberToEnroll.VIP_Member__c = True;
	                        }
	                        System.debug('trtest Address__c---'+subscriberToEnroll.Address__c);
	                        System.debug('trtest Address2__c---'+subscriberToEnroll.Address_2__c);
	                        System.debug('trtest City__c---'+subscriberToEnroll.City__c);
	                        System.debug('trtest State_province__c---'+subscriberToEnroll.State_Province__c);
		                        // IA DP-7080: New Logic to Capitalize Only FirsT Letter
		                    errorMessage = formatPatientDetails(patientToEnroll);
                            if (errorMessage!= null){
                                res.responseBody = Blob.valueOf(errorMessage);
                                res.statusCode = 500;
                                return;
                            }
		                        
                        subscriberToEnroll.Name__c = subscriberToEnroll.FirstName__c + ' ' + subscriberToEnroll.LastName__c;
                        
                        patientsToUpdate.add(subscriberToEnroll);
                    }
                    
                    if (!patientsToUpdate.isEmpty()) {
                        update patientsToUpdate;
                    }

                    // Create consent and carrier records only after the patient conversion/update succeeds.
                    createConsentFormRecord(patientId, patientToEnroll.Member_Journey_Cohort__c);

                    Carrier__c newCarrier = new Carrier__c();
                    if (mockMode == NULL) {
                        newCarrier = createCarrierRecord(patientToEnroll, foundBenefitOrder);
                    }

                    if (newCarrier != NULL && newCarrier.Coverage_Start_Date__c != NULL && foundBenefitOrder.Go_Live_Date__c != NULL && ((newCarrier.Coverage_Start_Date__c < foundBenefitOrder.Go_Live_Date__c) || (foundBenefitOrder.Benefit_Order_End_Date__c != NULL && newCarrier.Coverage_Start_Date__c > foundBenefitOrder.Benefit_Order_End_Date__c))) {
                        res.responseBody = Blob.valueOf('Coverage start date should not be less than benefit order start date or greater than benfit order end date');
                        res.statusCode = 500;
                        return;
                    }

                    createLinkedPatientCarrierRecords(patientToEnroll.Id, newCarrier);

                    if (enrollSubscriber) {
                        createConsentFormRecord(subscriberToEnroll.Id, subscriberToEnroll.Member_Journey_Cohort__c);

                        Carrier__c subscriberCarrier = new Carrier__c();
                        if (mockMode == NULL) {
                            subscriberCarrier = createCarrierRecord(subscriberToEnroll, foundBenefitOrder);
                        }

                        if (subscriberCarrier != NULL && subscriberCarrier.Coverage_Start_Date__c != NULL && foundBenefitOrder.Go_Live_Date__c != NULL && ((subscriberCarrier.Coverage_Start_Date__c < foundBenefitOrder.Go_Live_Date__c) || (foundBenefitOrder.Benefit_Order_End_Date__c != NULL && subscriberCarrier.Coverage_Start_Date__c > foundBenefitOrder.Benefit_Order_End_Date__c))) {
                            res.responseBody = Blob.valueOf('Coverage start date should not be less than benefit order start date or greater than benfit order end date');
                            res.statusCode = 500;
                            return;
                        }

                        createLinkedPatientCarrierRecords(subscriberToEnroll.Id, subscriberCarrier);
                    }
                    
                    res.statusCode = 200;
                }
            }
            
        } catch (Exception ex) {
            Database.rollback(sp);
            System.debug('EXCEPTION EX: ' + ex.getMessage() + ' LINE NUMBER: ' + ex.getLineNumber());
            String jsonRequestString = req.requestBody.toString();
            DOCheckEligibilityRestService.createCalloutHandlerRecord(ex, patientId, jsonRequestString, '500');
            
            // if anything fails -- create case
            ProgynyCreateDigitalOnboardingCase.createDigitalOnboardingCase(patientToEnroll.Email__c, patientToEnroll.Enterprise_Account__c, patientToEnroll.Id, ex.getMessage());            
            
            res.responseBody = Blob.valueOf(ex.getMessage());
            res.statusCode = 500;
        }
    }
    
    // comes from ConvertToEnterpriseController.apxc
    public static Boolean validateSelectedBenefit(String selectedBenefit) {
        String upperCaseSelectedBenefit = selectedBenefit.toUpperCase();
        Boolean benefitMatch = false;
        for (String str : System.Label.Novartis_Plan_Names.split(';')) {
            if (str == upperCaseSelectedBenefit) {
                benefitMatch = true;
                break;
            }    
        }
        
        return benefitMatch;
    }
    
    // creates consent form record to indicate what disclaimers the patient has read and agreed to
    private static void createConsentFormRecord(String patientId, String journeyChosen) {
        Consent_Form__c consentFormObj = new Consent_Form__c();
        consentFormObj.Patient__c = patientId;
        consentFormObj.Date_Completed__c = System.now();
        
        if (journeyChosen == 'Smart Cycle') {
            Id fertilityRecordTypeId = Schema.SObjectType.Consent_Form__c.getRecordTypeInfosByName().get('Fertility').getRecordTypeId();    
            consentFormObj.RecordTypeId = fertilityRecordTypeId;
            consentFormObj.Medical_Disclaimer__c = true;
            consentFormObj.Provider_Disclaimer__c = true;
            consentFormObj.Financial_Disclaimer__c = true;
        } else if (journeyChosen == 'Menopause') {
            Id menopauseRecordTypeId = Schema.SObjectType.Consent_Form__c.getRecordTypeInfosByName().get('Menopause').getRecordTypeId();    
            consentFormObj.RecordTypeId = menopauseRecordTypeId;
            consentFormObj.Medical_Disclaimer__c = true;
            consentFormObj.Provider_Disclaimer__c = true;
            consentFormObj.Financial_Disclaimer__c = true;
        } else if (journeyChosen == 'Preconception') {
            Id preconceptionRecordTypeId = Schema.SObjectType.Consent_Form__c.getRecordTypeInfosByName().get('Preconception').getRecordTypeId();    
            consentFormObj.RecordTypeId = preconceptionRecordTypeId;
            consentFormObj.Medical_Disclaimer__c = true;
            consentFormObj.Provider_Disclaimer__c = true;
            consentFormObj.Financial_Disclaimer__c = true;
        } else if (journeyChosen == 'Pregnancy') {
            Id pregnancyRecordTypeId = Schema.SObjectType.Consent_Form__c.getRecordTypeInfosByName().get('Pregnancy').getRecordTypeId();    
            consentFormObj.RecordTypeId = pregnancyRecordTypeId;
            consentFormObj.Medical_Disclaimer__c = true;
        } else if (journeyChosen == 'Postpartum') {
            Id postpartumRecordTypeId = Schema.SObjectType.Consent_Form__c.getRecordTypeInfosByName().get('Postpartum').getRecordTypeId();    
            consentFormObj.RecordTypeId = postpartumRecordTypeId;
            consentFormObj.Medical_Disclaimer__c = true;
        }
        
        insert consentFormObj;        
    }
    
    // creates carrier records associated to newly eligible patients
    private static Carrier__c createCarrierRecord(Patient__c patient, Benefit_Order__c foundBO) {     
        Carrier__c newCarrier = new Carrier__c();
        //ProgynyCarrierHelper.runCarrierTrigger = false;
        
        //IA DP-7155: Get Record Type Id for 'Enterprise Coverage' to avoid validation rule failure
        Id enterpriseCoverageRecordTypeId = Schema.SObjectType.Carrier__c.getRecordTypeInfosByName().get('Enterprise Coverage').getRecordTypeId();
        
        String relationToSubscriber = patient.Relation_to_Primary_Subscriber__c;
        if (patient.Relation_to_Primary_Subscriber__c.toLowerCase() != 'subscriber') {
            relationToSubscriber = 'DEPENDENT';
        }
        
        List<Benefit_Order__c> currentBO = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :patient.Enterprise_Account__c
                                            AND Go_Live_Date__c <= TODAY
                                                            AND Benefit_Order_End_Date__c >= TODAY];
        
        if (!currentBO.isEmpty()) {
            //trtest temp comment             List<Member_Health_Plan__c> mphs = [SELECT Id, Payer_Name__c, Eligibility_Payor_ID__c, Claims_Process__c
            List<Member_Health_Plan__c> mphs = [SELECT Id, Name, Payer_Name__c, Eligibility_Payor_ID__c, Claims_Process__c
                                                FROM Member_Health_Plan__c WHERE Name = :patient.Member_Health_Plan__c
                                                AND Benefit_Order__c = :currentBO[0].Id
                                               ];
            
            if (!mphs.isEmpty()) {
                Map<String, Carrier__c> existingCarrierMap = new Map<String, Carrier__c>();
                List<Carrier__c> existingCarriers = [SELECT Id, RecordTypeId, Coverage_Start_Date__c, Coverage_End_Date__c, 
                                                     Relation_to_Primary_Subscriber__c, Selected_Benefit__c, Carrier_Member_Id__c, 
                                                     Member_Health_Plan__c, Payer_Name__c, Payor_ID__c,Group_Number__c,
                                                     Run_Accumulator__c, Plan_Type__c, Plan_Year__c, Patient__c
                                                     FROM Carrier__c WHERE Patient__c = :patient.Id];
                for (Carrier__c c : existingCarriers) {
                    existingCarrierMap.put(c.Plan_Year__c, c);
                }

                Carrier__c matchingCarrier = findMatchingPatientCarrier(existingCarriers, foundBO, mphs[0].Id, patient.Coverage_Start_Date__c);
                if (matchingCarrier != NULL) {
                    Map<Id, Carrier__c> oldCarrierMap = new Map<Id, Carrier__c>{
                        matchingCarrier.Id => new Carrier__c(
                            Id = matchingCarrier.Id,
                            Patient__c = matchingCarrier.Patient__c,
                            Plan_Year__c = matchingCarrier.Plan_Year__c,
                            Member_Health_Plan__c = matchingCarrier.Member_Health_Plan__c,
                            Coverage_Start_Date__c = matchingCarrier.Coverage_Start_Date__c,
                            Coverage_End_Date__c = matchingCarrier.Coverage_End_Date__c
                        )
                    };
                    matchingCarrier.Member_Health_Plan__c = mphs[0].Id;
                    // Carrier triggers are intentionally suppressed during enrollment; mirror the
                    // Member Health Plan name onto Selected Benefit here instead.
                    matchingCarrier.Selected_Benefit__c = mphs[0].Name; //trtest temp add
                    matchingCarrier.Payer_Name__c = mphs[0].Payer_Name__c;
                    matchingCarrier.Payor_ID__c = mphs[0].Eligibility_Payor_ID__c;
                    matchingCarrier.Run_Accumulator__c = ConvertToEnterpriseController.VALID_CLAIMS_PROCESS_STATUSES_TO_RUN_ACCUMULATOR.contains(mphs[0].Claims_Process__c);
                    matchingCarrier.Plan_Year__c = foundBO.Plan_Year__c;
                    //applyInsuranceIdCheck(matchingCarrier, oldCarrierMap);
                    update matchingCarrier;
                    newCarrier = matchingCarrier;
                
                // clone existing carrier with different plan year -- if one does not exist for this year
                } else if (!existingCarrierMap.isEmpty() && existingCarrierMap.get(foundBO.Plan_Year__c) == NULL) {
                    // be able to get the previous years carrier record
                    Integer planYearInteger = Integer.valueof(foundBO.Plan_Year__c);
                    Integer prevYearInteger = planYearInteger - 1;
                    Carrier__c prevYearCarrier = existingCarrierMap.get(String.valueOf(prevYearInteger));
                    if (prevYearCarrier != NULL) { 
                        // CLONE PREV YEAR CARRIER
                        newCarrier = prevYearCarrier.clone();
                        newCarrier.Coverage_Start_Date__c = foundBO.Go_Live_Date__c;
                        newCarrier.Coverage_End_Date__c = foundBO.Benefit_Order_End_Date__c;
                        newCarrier.Member_Health_Plan__c = mphs[0].Id;
                        newCarrier.Selected_Benefit__c = mphs[0].Name;//trtest temp add
                        newCarrier.Payer_Name__c = mphs[0].Payer_Name__c;
                        newCarrier.Payor_ID__c = mphs[0].Eligibility_Payor_ID__c;
                        newCarrier.Plan_Year__c = foundBO.Plan_Year__c;
                        newCarrier.RecordTypeId = enterpriseCoverageRecordTypeId;
                        //applyInsuranceIdCheck(newCarrier, null);
                        insert newCarrier;
                    } else {
                        newCarrier.Patient__c = patient.Id;
                        newCarrier.Coverage_Start_Date__c = patient.Coverage_Start_Date__c;
                        newCarrier.Coverage_End_Date__c = foundBO.Benefit_Order_End_Date__c;
                        newCarrier.Relation_to_Primary_Subscriber__c = relationToSubscriber;
                        // Intentionally do not copy Patient__c.Selected_Benefit__c to coverage during enrollment.
                        // newCarrier.Selected_Benefit__c = patient.Selected_Benefit__c != NULL ? patient.Selected_Benefit__c : NULL;
                        // Carrier triggers are intentionally suppressed during enrollment; use the
                        // associated Member Health Plan rather than Patient__c.Selected_Benefit__c.
                        newCarrier.Selected_Benefit__c = mphs[0].Name;//trtest temp added
                        newCarrier.Carrier_Member_Id__c = patient.Carrier_Member_ID__c;
                        newCarrier.Member_Health_Plan__c = mphs[0].Id;
                        newCarrier.Payer_Name__c = mphs[0].Payer_Name__c;
                        newCarrier.Payor_ID__c = mphs[0].Eligibility_Payor_ID__c;
                        newCarrier.Run_Accumulator__c = ConvertToEnterpriseController.VALID_CLAIMS_PROCESS_STATUSES_TO_RUN_ACCUMULATOR.contains(mphs[0].Claims_Process__c);
                        newCarrier.Plan_Year__c = foundBO.Plan_Year__c;
                        newCarrier.Plan_Type__c =  patient.Plan_Type__c;
                        newCarrier.RecordTypeId = enterpriseCoverageRecordTypeId;
                        newCarrier.Group_number__c = patient.Group_number__c;
                        //applyInsuranceIdCheck(newCarrier, null);
                        insert newCarrier;
                    }
                    
                    // update existing carrier if has current plan year found in query
                } else if (!existingCarrierMap.isEmpty() && existingCarrierMap.get(foundBO.Plan_Year__c) != NULL) {
                    Carrier__c existingCarrier = existingCarrierMap.get(foundBO.Plan_Year__c);
                    Map<Id, Carrier__c> oldCarrierMap = new Map<Id, Carrier__c>{
                        existingCarrier.Id => new Carrier__c(
                            Id = existingCarrier.Id,
                            Patient__c = existingCarrier.Patient__c,
                            Plan_Year__c = existingCarrier.Plan_Year__c,
                            Member_Health_Plan__c = existingCarrier.Member_Health_Plan__c,
                            Coverage_Start_Date__c = existingCarrier.Coverage_Start_Date__c,
                            Coverage_End_Date__c = existingCarrier.Coverage_End_Date__c
                        )
                    };
                    existingCarrier.Member_Health_Plan__c = mphs[0].Id;
                    existingCarrier.Selected_Benefit__c = mphs[0].Name;
                    existingCarrier.Payer_Name__c = mphs[0].Payer_Name__c;
                    existingCarrier.Payor_ID__c = mphs[0].Eligibility_Payor_ID__c;
                    existingCarrier.Run_Accumulator__c = ConvertToEnterpriseController.VALID_CLAIMS_PROCESS_STATUSES_TO_RUN_ACCUMULATOR.contains(mphs[0].Claims_Process__c);
                    existingCarrier.Plan_Year__c = foundBO.Plan_Year__c;
                    //applyInsuranceIdCheck(existingCarrier, oldCarrierMap);
                    update existingCarrier;
                    
                    // assign to new carrier in order to return
                    newCarrier = existingCarrier;
                    
                } else if (existingCarrierMap.isEmpty()) { // insert new carrier if there are no previous carriers
                    newCarrier.Patient__c = patient.Id;
                    newCarrier.Coverage_Start_Date__c = patient.Coverage_Start_Date__c;
                    newCarrier.Coverage_End_Date__c = foundBO.Benefit_Order_End_Date__c;
                    newCarrier.Relation_to_Primary_Subscriber__c = relationToSubscriber;
                    // Intentionally do not copy Patient__c.Selected_Benefit__c to coverage during enrollment.
                    // newCarrier.Selected_Benefit__c = patient.Selected_Benefit__c != NULL ? patient.Selected_Benefit__c : NULL;
                    // Carrier triggers are intentionally suppressed during enrollment; use the
                    // associated Member Health Plan rather than Patient__c.Selected_Benefit__c.
                    newCarrier.Selected_Benefit__c = mphs[0].Name;
                    newCarrier.Carrier_Member_Id__c = patient.Carrier_Member_ID__c;
                    newCarrier.Member_Health_Plan__c = mphs[0].Id;
                    newCarrier.Payer_Name__c = mphs[0].Payer_Name__c;
                    newCarrier.Payor_ID__c = mphs[0].Eligibility_Payor_ID__c;
                    newCarrier.Run_Accumulator__c = ConvertToEnterpriseController.VALID_CLAIMS_PROCESS_STATUSES_TO_RUN_ACCUMULATOR.contains(mphs[0].Claims_Process__c);
                    newCarrier.Plan_Year__c = foundBO.Plan_Year__c;
                    newCarrier.Plan_Type__c =  patient.Plan_Type__c;
                    newCarrier.Group_number__c =  patient.Group_number__c;
                    newCarrier.RecordTypeId = enterpriseCoverageRecordTypeId;
                    
                    //applyInsuranceIdCheck(newCarrier, null);
                    insert newCarrier;
                }
            }
        }
        // Carrier triggers are disabled for enrollment DML. Explicitly mirror the
        // Member Health Plan-derived coverage benefit back to the Patient record.
        updatePatientSelectedBenefitFromCarriers(new List<Carrier__c>{ newCarrier });
        return newCarrier;
    }

    private static Carrier__c findMatchingPatientCarrier(List<Carrier__c> existingCarriers, Benefit_Order__c foundBO, Id memberHealthPlanId, Date coverageStartDate) {
        if (existingCarriers == null || existingCarriers.isEmpty()) {
            return null;
        }

        Date sourceStart = coverageStartDate == null ? foundBO.Go_Live_Date__c : coverageStartDate;
        Date sourceEnd = foundBO.Benefit_Order_End_Date__c;

        for (Carrier__c existingCarrier : existingCarriers) {
            if (existingCarrier.Plan_Year__c != null && existingCarrier.Plan_Year__c == foundBO.Plan_Year__c) {
                return existingCarrier;
            }

            if (existingCarrier.Plan_Year__c == null
                && memberHealthPlanId != null
                && existingCarrier.Member_Health_Plan__c == memberHealthPlanId
                && carrierDatesOverlap(existingCarrier.Coverage_Start_Date__c, existingCarrier.Coverage_End_Date__c, sourceStart, sourceEnd)) {
                return existingCarrier;
            }
        }

        return null;
    }

    private static void createLinkedPatientCarrierRecords(Id sourcePatientId, Carrier__c sourceCarrier) {
        if (sourcePatientId == null || sourceCarrier == null || sourceCarrier.Id == null) {
            return;
        }

        Carrier__c source = [
            SELECT Id,
                   Patient__c,
                   RecordTypeId,
                   Coverage_Start_Date__c,
                   Coverage_End_Date__c,
                   Relation_to_Primary_Subscriber__c,
                   Selected_Benefit__c,
                   Carrier_Member_Id__c,
                   Member_Health_Plan__c,
                   Member_Health_Plan__r.Name,//trtest temp add
                   Payer_Name__c,
                   Payor_ID__c,
                   Run_Accumulator__c,
                   Plan_Type__c,
                   Plan_Year__c,
            		Group_Number__c
            FROM Carrier__c
            WHERE Id = :sourceCarrier.Id
            LIMIT 1
        ];

        if (source.Plan_Year__c == null || source.RecordTypeId == null) {
            return;
        }

        Patient__c sourcePatient = [
            SELECT Id,
                   Primary_Subscriber__c
            FROM Patient__c
            WHERE Id = :sourcePatientId
            LIMIT 1
        ];

        Set<Id> linkedPatientIds = new Set<Id>();
        if (sourcePatient.Primary_Subscriber__c != null) {
            linkedPatientIds.add(sourcePatient.Primary_Subscriber__c);
        }

        Id subscriberId = sourcePatient.Primary_Subscriber__c == null ? sourcePatient.Id : sourcePatient.Primary_Subscriber__c;
        for (Patient__c dependent : [
            SELECT Id
            FROM Patient__c
            WHERE Primary_Subscriber__c = :subscriberId
        ]) {
            linkedPatientIds.add(dependent.Id);
        }

        linkedPatientIds.remove(sourcePatientId);
        if (linkedPatientIds.isEmpty()) {
            return;
        }

        Map<Id, Patient__c> linkedPatients = new Map<Id, Patient__c>([
            SELECT Id,
                   RecordType.Name,
                   Relation_to_Primary_Subscriber__c,
                   Carrier_Member_ID__c
            FROM Patient__c
            WHERE Id IN :linkedPatientIds
        ]);

        Map<Id, List<Carrier__c>> existingCarriersByPatientId = new Map<Id, List<Carrier__c>>();
        for (Carrier__c existingCarrier : [
            SELECT Id,
                   Patient__c,
                   Plan_Year__c,
                   Member_Health_Plan__c,
                   Coverage_Start_Date__c,
                   Coverage_End_Date__c
            FROM Carrier__c
            WHERE Patient__c IN :linkedPatientIds
            AND RecordTypeId = :source.RecordTypeId
        ]) {
            if (!existingCarriersByPatientId.containsKey(existingCarrier.Patient__c)) {
                existingCarriersByPatientId.put(existingCarrier.Patient__c, new List<Carrier__c>());
            }
            existingCarriersByPatientId.get(existingCarrier.Patient__c).add(existingCarrier);
        }

        List<Carrier__c> carriersToInsert = new List<Carrier__c>();
        for (Patient__c linkedPatient : linkedPatients.values()) {
            if (linkedPatient.RecordType == null || linkedPatient.RecordType.Name != 'Enterprise') {
                continue;
            }
            if (hasMatchingLinkedCarrier(existingCarriersByPatientId.get(linkedPatient.Id), source)) {
                continue;
            }

            Carrier__c linkedCarrier = new Carrier__c();
            linkedCarrier.Patient__c = linkedPatient.Id;
            linkedCarrier.RecordTypeId = source.RecordTypeId;
            linkedCarrier.Coverage_Start_Date__c = source.Coverage_Start_Date__c;
            linkedCarrier.Coverage_End_Date__c = source.Coverage_End_Date__c;
            linkedCarrier.Relation_to_Primary_Subscriber__c = getCarrierRelationToSubscriber(linkedPatient);
            // Intentionally do not propagate Selected Benefit to linked-patient coverage during enrollment.
            // linkedCarrier.Selected_Benefit__c = source.Selected_Benefit__c;
            // Carrier triggers are intentionally suppressed during enrollment; use the linked
            // coverage's Member Health Plan name rather than propagating the source value.
            linkedCarrier.Selected_Benefit__c = source.Member_Health_Plan__r == null
                ? null
                : source.Member_Health_Plan__r.Name;//trtest temp add
            linkedCarrier.Carrier_Member_Id__c = linkedPatient.Carrier_Member_ID__c;
            linkedCarrier.Member_Health_Plan__c = source.Member_Health_Plan__c;
            linkedCarrier.Payer_Name__c = source.Payer_Name__c;
            linkedCarrier.Payor_ID__c = source.Payor_ID__c;
            linkedCarrier.Run_Accumulator__c = source.Run_Accumulator__c;
            linkedCarrier.Plan_Type__c = source.Plan_Type__c;
            linkedCarrier.Plan_Year__c = source.Plan_Year__c;
            linkedCarrier.Group_number__c = source.Group_number__c;
            //applyInsuranceIdCheck(linkedCarrier, null);
            carriersToInsert.add(linkedCarrier);
        }

        if (!carriersToInsert.isEmpty()) {
            Boolean oldRunCarrierTrigger = ProgynyCarrierHelper.runCarrierTrigger;
            Boolean oldRunCarrierAfter = ProgynyCarrierHelper.runCarrierAfterInsertAndUpdate;
            try {
                //ProgynyCarrierHelper.runCarrierTrigger = false;
                //ProgynyCarrierHelper.runCarrierAfterInsertAndUpdate = false;
                insert carriersToInsert;
            } finally {
                ProgynyCarrierHelper.runCarrierTrigger = oldRunCarrierTrigger;
                ProgynyCarrierHelper.runCarrierAfterInsertAndUpdate = oldRunCarrierAfter;
            }
            //trtest temp added
			// Linked coverage is also inserted with Carrier triggers disabled.
            updatePatientSelectedBenefitFromCarriers(carriersToInsert);
			//trest temp added end
        }
    }
	//trtest temp added start
    /**
     * Keeps Patient__c.Selected_Benefit__c aligned with the benefit selected on
     * enrollment-created coverage when ProgynyCarrierTrigger is intentionally off.
     */
    private static void updatePatientSelectedBenefitFromCarriers(List<Carrier__c> carriers) {
        Map<Id, String> benefitByPatientId = new Map<Id, String>();
        for (Carrier__c carrier : carriers) {
            if (carrier != null
                && carrier.Patient__c != null
                && !String.isBlank(carrier.Selected_Benefit__c)) {
                benefitByPatientId.put(carrier.Patient__c, carrier.Selected_Benefit__c);
            }
        }

        if (benefitByPatientId.isEmpty()) {
            return;
        }

        List<Patient__c> patientsToUpdate = new List<Patient__c>();
        for (Id patientId : benefitByPatientId.keySet()) {
            patientsToUpdate.add(new Patient__c(
                Id = patientId,
                Selected_Benefit__c = benefitByPatientId.get(patientId)
            ));
        }

        if (!patientsToUpdate.isEmpty()) {
            update patientsToUpdate;
        }
    }
    
	@TestVisible
    private static Boolean hasMatchingLinkedCarrier(List<Carrier__c> existingCarriers, Carrier__c source) {
        if (existingCarriers == null || existingCarriers.isEmpty()) {
            return false;
        }

        for (Carrier__c existingCarrier : existingCarriers) {
            if (existingCarrier.Plan_Year__c != null && existingCarrier.Plan_Year__c == source.Plan_Year__c) {
                return true;
            }

            if (existingCarrier.Plan_Year__c == null
                && source.Member_Health_Plan__c != null
                && existingCarrier.Member_Health_Plan__c == source.Member_Health_Plan__c
                && carrierDatesOverlap(existingCarrier, source)) {
                return true;
            }
        }

        return false;
    }
    
	@TestVisible
    private static Boolean carrierDatesOverlap(Carrier__c existingCarrier, Carrier__c source) {
        return carrierDatesOverlap(
            existingCarrier.Coverage_Start_Date__c,
            existingCarrier.Coverage_End_Date__c,
            source.Coverage_Start_Date__c,
            source.Coverage_End_Date__c
        );
    }

    private static Boolean carrierDatesOverlap(Date existingCoverageStartDate, Date existingCoverageEndDate, Date sourceCoverageStartDate, Date sourceCoverageEndDate) {
        Date existingStart = existingCoverageStartDate == null ? Date.newInstance(1900, 1, 1) : existingCoverageStartDate;
        Date existingEnd = existingCoverageEndDate == null ? Date.newInstance(4000, 12, 31) : existingCoverageEndDate;
        Date sourceStart = sourceCoverageStartDate == null ? Date.newInstance(1900, 1, 1) : sourceCoverageStartDate;
        Date sourceEnd = sourceCoverageEndDate == null ? Date.newInstance(4000, 12, 31) : sourceCoverageEndDate;

        return existingStart <= sourceEnd && sourceStart <= existingEnd;
    }
    
	@TestVisible
    private static String getCarrierRelationToSubscriber(Patient__c patient) {
        if (patient == null || String.isBlank(patient.Relation_to_Primary_Subscriber__c)) {
            return null;
        }

        return patient.Relation_to_Primary_Subscriber__c.toLowerCase() == 'subscriber'
            ? patient.Relation_to_Primary_Subscriber__c
            : 'DEPENDENT';
    }
    
    @TestVisible
    private static void applyInsuranceIdCheck(Carrier__c carrier, Map<Id, Carrier__c> oldCarrierMap) {
        if (carrier == null || carrier.Plan_Year__c == null || carrier.Patient__c == null) {
            return;
        }

        ProgynyCarrierHelper.InsuranceIdCheck(
            new Set<String>{ carrier.Plan_Year__c },
            new Set<Id>{ carrier.Patient__c },
            new List<Carrier__c>{ carrier },
            oldCarrierMap
        );
    }
    //trtest added 
    public static String formatPatientDetails(Patient__c patientObj) {
        
        String errorMessage = null;
        // IA DP-7080: New Logic to Capitalize Only FirsT Letter
        patientObj.FirstName__c = capitalizeFirstLetter(patientObj.FirstName__c);
        patientObj.LastName__c = capitalizeFirstLetter(patientObj.LastName__c); 
        
        // Normalize State to 2-char abbreviation for all record types
        if (String.isNotBlank(patientObj.State_Province__c)) {
            String upperState = patientObj.State_Province__c.trim().toUpperCase();
            String lowerState = patientObj.State_Province__c.trim().toLowerCase();
            if (States__c.getInstance(upperState) != null) {
                patientObj.State_Province__c = States__c.getInstance(upperState).State__c;
            } else if (States__c.getInstance(lowerState) != null) {
                patientObj.State_Province__c = States__c.getInstance(lowerState).State__c;
            } else if (ProgynyPatientHelper.states.contains(upperState)) {
                patientObj.State_Province__c = upperState;
            }
        }
        
        if (patientObj.RecordTypeId <> Schema.SObjectType.Patient__c.getRecordTypeInfosByName().get('Enterprise').getRecordTypeId() || patientObj.Enterprise_Account__c == null) {
            errorMessage += 'Patient is not Enterprised or no Enterprise Account linked to the patient; ';
        }
        
        if (patientObj.Gender__c == null || ( patientObj.Gender__c.toLowerCase() <> 'male' && patientObj.Gender__c.toLowerCase() <> 'female'  && patientObj.Gender__c.toLowerCase() <> 'm' && patientObj.Gender__c.toLowerCase() <> 'f')) {
            errorMessage +='Gender should be Male or Female; ';
        } else {
            patientObj.Gender__c = (patientObj.Gender__c.substring(0,1)).toUpperCase();
        }
        
        if(!System.isFuture() && !System.isBatch() && !System.isQueueable() && !System.isScheduled()){
            if( patientObj.Relation_to_Primary_Subscriber__c == null)
            {
                errorMessage += 'Relationship is mandatory for Patient creation; ';
            }
            else if(patientObj.Relation_to_Primary_Subscriber__c.equalsIgnoreCase('Spouse') || patientObj.Relation_to_Primary_Subscriber__c.equalsIgnoreCase('Domestic Partner') || patientObj.Relation_to_Primary_Subscriber__c.equalsIgnoreCase('Life Partner') || patientObj.Relation_to_Primary_Subscriber__c.equalsIgnoreCase('Dependent') )
            {
                patientObj.Relation_to_Primary_Subscriber__c = 'DEPENDENT';
            }
            else if(patientObj.Relation_to_Primary_Subscriber__c.equalsIgnoreCase('Subscriber') || patientObj.Relation_to_Primary_Subscriber__c.equalsIgnoreCase('SELF') )
            {
                patientObj.Relation_to_Primary_Subscriber__c = 'SUBSCRIBER';
            }
            else if(patientObj.Relation_to_Primary_Subscriber__c.equalsIgnoreCase('Child') )
            {
                patientObj.Relation_to_Primary_Subscriber__c = 'CHILD';
            }
            else
            {
                errorMessage += 'Invalid relationship Status; ';
            }
        }
        //patientObj.Coverage_End_Date__c = patientObj.Coverage_End_Date__c <> null && patientObj.Coverage_End_Date__c > system.toDay() ? NULL : patientObj.Coverage_End_Date__c;
        patientObj.Coverage_Tier_Elected__c = 'EE ONLY';
        // IA Commnetd as par of DP-7080 as the logic exist above
        /*patientObj.FirstName__c = patientObj.FirstName__c <> null ? patientObj.FirstName__c.toUpperCase() : patientObj.FirstName__c;
        patientObj.LastName__c = patientObj.LastName__c <> null ? patientObj.LastName__c.toUpperCase() : patientObj.LastName__c;*/
        
        if (patientObj.International_Address__c == true) {
            errorMessage += 'Patient has Internation Address; ' ;
        }
        validateAndFormatAddress( patientObj, errorMessage);
        return errorMessage;
    }//trtest added
    
    public static void validateAndFormatAddress(Patient__c patientObj, String errorMessage) {

        if( patientObj.Address__c == null || patientObj.Address__c.length() == 1 )
        {
            errorMessage += 'A valid Address is Mandatory for Patient creation; ';
        }
        else
        {
            string add1 = patientObj.Address__c.toUpperCase();
            if( patientObj.Address_2__c == null && ( add1.indexOf('APT ') > -1 || add1.indexOf('APARTMENT ') > -1 ))
            {
                integer indx = add1.indexOf('APT ') > -1 ? add1.indexOf('APT ') : add1.indexOf('APT.') > -1 ? add1.indexOf('APT.') : add1.indexOf('APARTMENT ');
                // Address_2_length_validation fails when > 20 chars; keep overflow in Address__c instead of extracting.
                if( add1.length() - indx <= 20 ){
                    patientObj.Address_2__c = add1.substring( indx, add1.length() ) ;
                    add1 = add1.substring(0,indx);
                }
            }
            if( patientObj.Address_2__c == null && ( add1.indexOf('APT#') > -1 || add1.indexOf('APARTMENT#') > -1 ) )
            {
                integer indx = add1.indexOf('APT#') > -1 ? add1.indexOf('APT#') : add1.indexOf('APARTMENT#');
                if( add1.length() - indx <= 20 ){
                    patientObj.Address_2__c = add1.substring( indx, add1.length() ) ;
                    add1 = add1.substring(0,indx);
                }
            }
            
            else if( patientObj.Address_2__c == null && ( add1.indexOf('APT.') > -1 || add1.indexOf('APARTMENT.') > -1 ))
            {
                integer indx = add1.indexOf('APT.') > -1 ? add1.indexOf('APT.') : add1.indexOf('APARTMENT.');
                if( add1.length() - indx <= 20 ){
                    patientObj.Address_2__c = add1.substring( indx, add1.length() ) ;
                    add1 = add1.substring(0,indx);
                }
            }
            
            else if( patientObj.Address_2__c == null && ( add1.indexOf('UNIT') > -1 || add1.indexOf('UNIT.') > -1 ))
            {
                integer indx = add1.indexOf('UNIT') > -1 ? add1.indexOf('UNIT') : add1.indexOf('UNIT.');
                if( add1.length() - indx <= 20 ){
                    patientObj.Address_2__c = add1.substring( indx, add1.length() ) ;
                    add1 = add1.substring(0,indx);
                }
            }
            else if( patientObj.Address_2__c == null && add1.indexOf('#') > -1 )
            {
                integer indx = add1.indexOf('#') ;
                if( add1.length() - indx <= 20 ){
                    patientObj.Address_2__c = add1.substring( indx, add1.length() ) ;
                    add1 = add1.substring(0,indx);
                }
            }
            patientObj.Address__c = add1;
        }
        
        patientObj.Address_2__c = patientObj.Address__c == patientObj.Address_2__c ? null :
        patientObj.Address_2__c <> null ? patientObj.Address_2__c.toUpperCase() : patientObj.Address_2__c;
        if( patientObj.PostalCode__c <> null )
        {
            string zip = (patientObj.PostalCode__c.replaceAll('-','')).replaceAll(' ','');
            if( patientObj.Country__c == 'USA' ){
                if( !zip.isNumeric() || zip.length() < 5)
                {
                    errorMessage += 'Zip Code Format is incorrect, please pass 5 digit Zip codes only; ';
                }
                else
                {
                    patientObj.PostalCode__c = zip.substring(0,5);
                }
            }if( patientObj.Country__c == 'CAN' ){
                if(zip.length() != 6 || zip.isNumeric()  ){
                    errorMessage += 'Zip Code Format is incorrect; ';
                }
            }
        }
        
        if( patientObj.City__c <> null )
        {
            if( patientObj.City__c.length() == 1)
            {
                errorMessage += 'City Could not be Identified, please verify; ';
            }
            else
                patientObj.City__c = patientObj.City__c.toUpperCase();
        }
        else
        {
            errorMessage += 'Please enter City; ';
        }
        
        if( patientObj.State_Province__c == null )
        {
            errorMessage += 'State is required; ';
        } else if (patientObj.Country__c == 'USA' || patientObj.Country__c == 'CAN') {
            String state = patientObj.State_Province__c;
            String upperState = state.toUpperCase();
            String lowerState = state.toLowerCase();
            if (States__c.getInstance(upperState) != null) {
                patientObj.State_Province__c = States__c.getInstance(upperState).State__c;
            } else if (States__c.getInstance(lowerState) != null) {
                patientObj.State_Province__c = States__c.getInstance(lowerState).State__c;
            } else if (ProgynyPatientHelper.states.contains(upperState)) {
                patientObj.State_Province__c = upperState;
            } else if (ProgynyPatientHelper.states.contains(lowerState)) {
                patientObj.State_Province__c = lowerState;
            } else {
                errorMessage += 'State could not be identified, please verify; ';
            }
        }  
    }
	private static String capitalizeFirstLetter(String input) {
        if (input != null && input.length() > 0) {
            return input.substring(0, 1).toUpperCase() +
                   (input.length() > 1 ? input.substring(1).toLowerCase() : '');
        }
        return input;
    }
    
    private static void createChildrens(List<Object> childrens, String patientId) {
        List<Children__c> childrenToUpsert = new List<Children__c>();
        for (Object childObj : childrens) {
            Map<String, Object> child = (Map<String, Object>)childObj;
            childrenToUpsert.add(new Children__c(
                Patient__c = patientId,
                Child_First_Name__c = (String) child.get('first_name'),
                Date_of_Birth__c = date.valueOf((String) child.get('date_of_birth'))
            ));
        }
        if (!childrenToUpsert.isEmpty()) {
            upsert childrenToUpsert;
        }
    }
}
