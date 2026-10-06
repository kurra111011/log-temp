/**
* @author: Grace Saint
* @createddate: 5/6/2024
* @description: Test class for DOEnrollmentRestService.apxc
**/ 

@isTest
public class DOEnrollmentRestServiceTest {
    
    @testSetup static void setup() {
        ProgynyStaticFuture.executePatientTrg = false;
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyCarrierHelper.runCarrierTrigger = false;
        ProgynyAccountTriggerHandler.isBeforeFirstTime = false;
        ProgynyAccountTriggerHandler.isAfterFirstTime = false;
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = ProgynyTestDataFactory.setupProgynyEnterpriseAccount('Enrollment Account');
        Id benefitOrderId = ProgynyTestDataFactory.setupBenefitOrder(testAccountId);
        Id testMemberhealthPlan = ProgynyTestDataFactory.setupMemberHelathPlan(benefitOrderId, testAccountId);        
    }

    private static void setupRestRequest(String requestBody) {
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestContext.request = request;
        RestContext.response = new RestResponse();
    }

    private static String fertilityRequestBody(Id patientId) {
        return '{"enrollment":[{"Id":"' + patientId + '","Product":"fertility","Medical_History__c" : "Oncofertility;Gender Reaffirming Surgery","Previous_Treatments__c":"IUI;IVF Fresh", "Preferred_timeline_for_initial_consult__c" : "As soon as possible","Preconception_Goals__c": "Less than 6 months","Estimated_Due_Date__c":"2025-01-01","Delivery_Date__c":"2025-01-01","What_support_is_the_member_looking_for__c" : "I\'m interested in nutrition and lifestyle support"}]}';
    }

    private static void createFertilitySupportBenefit(Id benefitOrderId, Id memberHealthPlanId, Boolean includeFertilityFap) {
        Id fertilitySupportRTId = Schema.SObjectType.Benefit_Product__c.getRecordTypeInfosByName().get('Fertility Support').getRecordTypeId();
        Benefit_Product__c supportBenefitProduct = new Benefit_Product__c(
            Benefit_Order__c = benefitOrderId,
            RecordTypeId = fertilitySupportRTId
        );
        insert supportBenefitProduct;

        insert new Member_Product__c(
            Benefit_Product__c = supportBenefitProduct.Id,
            Member_Health_Plan__c = memberHealthPlanId
        );

        if (includeFertilityFap) {
            Id fertilityFapRTId = Schema.SObjectType.Benefit_Product__c.getRecordTypeInfosByName().get('Fertility FAP').getRecordTypeId();
            insert new Benefit_Product__c(
                Benefit_Order__c = benefitOrderId,
                RecordTypeId = fertilityFapRTId
            );
        }
    }
    
    static testMethod void testEnrollMemberFertilityGeneral() {
        Test.startTest();
        
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;

        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        Patient__c testPatient = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Test', 'EnrollmentUser', 'Test.EnrollmentUser@progyny.com', '01/01/1980');
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"fertility","Medical_History__c" : "Oncofertility;Gender Reaffirming Surgery","Previous_Treatments__c":"IUI;IVF Fresh", "Preferred_timeline_for_initial_consult__c" : "As soon as possible","Preconception_Goals__c": "Less than 6 months","Estimated_Due_Date__c":"2025-01-01","Delivery_Date__c":"2025-01-01","What_support_is_the_member_looking_for__c" : "I\'m interested in nutrition and lifestyle support"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        // System.assert(RestContext.response.statusCode == 500);
    }
    
    static testMethod void testEnrollMemberFertility() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'EnrollmentUser', 'Test.EnrollmentUser@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"fertility","Medical_History__c" : "Oncofertility;Gender Reaffirming Surgery","Previous_Treatments__c":"IUI;IVF Fresh", "Preferred_timeline_for_initial_consult__c" : "As soon as possible","Preconception_Goals__c": "Less than 6 months","Estimated_Due_Date__c":"2025-01-01","Delivery_Date__c":"2025-01-01","What_support_is_the_member_looking_for__c" : "I\'m interested in nutrition and lifestyle support"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assert(RestContext.response.statusCode == 200);
    }
    
    static testMethod void testEnrollMemberPreconception() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'EnrollmentPreconception', 'Test.EnrollmentPreconception@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"preconception","Medical_History__c" : "Oncofertility;Gender Reaffirming Surgery","Previous_Treatments__c":"IUI;IVF Fresh", "Preferred_timeline_for_initial_consult__c" : "As soon as possible","Preconception_Goals__c": "Less than 6 months","Estimated_Due_Date__c":"2025-01-01","Delivery_Date__c":"2025-01-01","What_support_is_the_member_looking_for__c" : "I\'m interested in nutrition and lifestyle support"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assert(RestContext.response.statusCode == 200);
    }
    
    static testMethod void testEnrollMemberPregnancy() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'EnrollmentPregancy', 'Test.EnrollmentPregancy@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"pregnancy","Medical_History__c" : "Oncofertility;Gender Reaffirming Surgery","Previous_Treatments__c":"IUI;IVF Fresh", "Preferred_timeline_for_initial_consult__c" : "As soon as possible","Preconception_Goals__c": "Less than 6 months","Estimated_Due_Date__c":"2025-01-01","Delivery_Date__c":"2025-01-01","What_support_is_the_member_looking_for__c" : "I\'m interested in nutrition and lifestyle support"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        System.assert(RestContext.response.statusCode != 400);
    }
    
    static testMethod void testEnrollMemberPostpartum() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'EnrollmentPostpartum', 'Test.EnrollmentPostpartum@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"postpartum","Medical_History__c" : "Oncofertility;Gender Reaffirming Surgery","Previous_Treatments__c":"IUI;IVF Fresh", "Preferred_timeline_for_initial_consult__c" : "As soon as possible","Preconception_Goals__c": "Less than 6 months","Estimated_Due_Date__c":"2025-01-01","Delivery_Date__c":"2025-01-01","What_support_is_the_member_looking_for__c" : "I\'m interested in nutrition and lifestyle support"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        System.assert(RestContext.response.statusCode != 400);
    }
    
    static testMethod void testEnrollMemberMenopause() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'EnrollmentMenopause', 'Test.EnrollmentMenopause@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"menopause","Medical_History__c" : "Oncofertility;Gender Reaffirming Surgery","Previous_Treatments__c":"IUI;IVF Fresh", "Preferred_timeline_for_initial_consult__c" : "As soon as possible","Preconception_Goals__c": "Less than 6 months","Estimated_Due_Date__c":"2025-01-01","Delivery_Date__c":"2025-01-01","What_support_is_the_member_looking_for__c" : "I\'m interested in nutrition and lifestyle support"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        System.assert(RestContext.response.statusCode != 400);
    }
    
      static testMethod void testEnrollMemberParenting() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'EnrollmentParenting', 'Test.EnrollmentMenopause@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"parenting","Children__c": [{"first_name": "Andy","date_of_birth": "1995-05-04"},{"first_name": "Rahul","date_of_birth": "1995-05-04"}],"Medical_History__c" : "Oncofertility;Gender Reaffirming Surgery","Previous_Treatments__c":"IUI;IVF Fresh", "Preferred_timeline_for_initial_consult__c" : "As soon as possible","Preconception_Goals__c": "Less than 6 months","What_support_is_the_member_looking_for__c" : "I\'m interested in nutrition and lifestyle support"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        //System.assert(RestContext.response.statusCode == 200);
    }
    
    static testMethod void testEnrollMemberAdoption() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'EnrollmentAdoption', 'Test.EnrollmentAdoption@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"adoption","What_support_is_the_member_looking_for__c" : "I\'m interested in nutrition and lifestyle support"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        System.assert(RestContext.response.statusCode != 400);
    }
    
    static testMethod void testEnrollMemberSurrogacy() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'EnrollmentSurrogacy', 'Test.EnrollmentSurrogacy@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"surrogacy","What_support_is_the_member_looking_for__c" : "I\'m interested in nutrition and lifestyle support"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        System.assert(RestContext.response.statusCode != 400);
    }
    
    static testMethod void testEnrollMemberLBN() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'EnrollmentSurrogacy', 'Test.EnrollmentSurrogacy@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"benefits_navigation","What_support_is_the_member_looking_for__c" : "I\'m interested in nutrition and lifestyle support"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        System.assert(RestContext.response.statusCode != 400);
    }
    
    static testMethod void testEnrollMemberFertilityGeneralSubscriber() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];

        Patient__c testSubscriber = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Subscriber', 'EnrollmentUser', 'Subscriber.EnrollmentUser@progyny.com', '01/01/1981');
        Patient__c updatedSubscriber = [SELECT Eligibility_Status__c, Member_Health_Plan__c FROM Patient__c WHERE Id = :testSubscriber.Id];
        updatedSubscriber.Eligibility_Status__c = 'Active';
        updatedSubscriber.Member_Health_Plan__c = mphName.Name;
        update updatedSubscriber;
        
        Patient__c testPatient = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Test', 'EnrollmentUser', 'Test.EnrollmentUser@progyny.com', '01/01/1980');
        
        Patient__c updatePatientSubscriberLink = [SELECT Id, Primary_Subscriber__c, Relation_to_Primary_Subscriber__c, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatient.Id];
        updatePatientSubscriberLink.Primary_Subscriber__c = testSubscriber.Id;
        updatePatientSubscriberLink.Relation_to_Primary_Subscriber__c = 'Dependent';
        updatePatientSubscriberLink.Member_Health_Plan__c = mphName.Name;
        update updatePatientSubscriberLink;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"fertility","Medical_History__c" : "Oncofertility;Gender Reaffirming Surgery","Previous_Treatments__c":"IUI;IVF Fresh", "Preferred_timeline_for_initial_consult__c" : "As soon as possible","Preconception_Goals__c": "Less than 6 months","Estimated_Due_Date__c":"2025-01-01","Delivery_Date__c":"2025-01-01","What_support_is_the_member_looking_for__c" : "I\'m interested in nutrition and lifestyle support"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assert(RestContext.response.statusCode == 500);
    }
    
    static testMethod void testEnrollMemberPreconceptionSubscriber() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];

        Patient__c testSubscriber = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Subscriber', 'EnrollmentUser', 'Subscriber.EnrollmentUser@progyny.com', '01/01/1981');
        Patient__c updatedSubscriber = [SELECT Eligibility_Status__c, Member_Health_Plan__c FROM Patient__c WHERE Id = :testSubscriber.Id];
        updatedSubscriber.Eligibility_Status__c = 'Active';
        updatedSubscriber.Member_Health_Plan__c = mphName.Name;
        update updatedSubscriber;
        
        Patient__c testPatient = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Test', 'EnrollmentUser', 'Test.EnrollmentUser@progyny.com', '01/01/1980');
        
        Patient__c updatePatientSubscriberLink = [SELECT Id, Primary_Subscriber__c, Relation_to_Primary_Subscriber__c, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatient.Id];
        updatePatientSubscriberLink.Primary_Subscriber__c = testSubscriber.Id;
        updatePatientSubscriberLink.Relation_to_Primary_Subscriber__c = 'Dependent';
        updatePatientSubscriberLink.Member_Health_Plan__c = mphName.Name;
        update updatePatientSubscriberLink;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"preconception","Medical_History__c" : "Oncofertility;Gender Reaffirming Surgery","Previous_Treatments__c":"IUI;IVF Fresh", "Preferred_timeline_for_initial_consult__c" : "As soon as possible","Preconception_Goals__c": "Less than 6 months","Estimated_Due_Date__c":"2025-01-01","Delivery_Date__c":"2025-01-01","What_support_is_the_member_looking_for__c" : "I\'m interested in nutrition and lifestyle support"}]}';

        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assert(RestContext.response.statusCode == 500);
    }
    
    static testMethod void testEnrollMemberParentingSubscriber() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];

        Patient__c testSubscriber = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Subscriber', 'EnrollmentUser', 'Subscriber.EnrollmentUser@progyny.com', '01/01/1981');
        Patient__c updatedSubscriber = [SELECT Eligibility_Status__c, Member_Health_Plan__c FROM Patient__c WHERE Id = :testSubscriber.Id];
        updatedSubscriber.Eligibility_Status__c = 'Active';
        updatedSubscriber.Member_Health_Plan__c = mphName.Name;
        update updatedSubscriber;
        
        Patient__c testPatient = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Test', 'EnrollmentUser', 'Test.EnrollmentUser@progyny.com', '01/01/1980');
        
        Patient__c updatePatientSubscriberLink = [SELECT Id, Primary_Subscriber__c, Relation_to_Primary_Subscriber__c, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatient.Id];
        updatePatientSubscriberLink.Primary_Subscriber__c = testSubscriber.Id;
        updatePatientSubscriberLink.Relation_to_Primary_Subscriber__c = 'Dependent';
        updatePatientSubscriberLink.Member_Health_Plan__c = mphName.Name;
        update updatePatientSubscriberLink;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"parenting","Children__c": [{"first_name": "Andy","date_of_birth": "1995-05-04"},{"first_name": "Rahul","date_of_birth": "1995-05-04"}],"Medical_History__c" : "Oncofertility;Gender Reaffirming Surgery","Previous_Treatments__c":"IUI;IVF Fresh", "Preferred_timeline_for_initial_consult__c" : "As soon as possible","Preconception_Goals__c": "Less than 6 months","What_support_is_the_member_looking_for__c" : "I\'m interested in nutrition and lifestyle support"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assert(RestContext.response.statusCode == 500);
    }
    
    static testMethod void testEnrollMemberPregnancySubscriber() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];

        Patient__c testSubscriber = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Subscriber', 'EnrollmentUser', 'Subscriber.EnrollmentUser@progyny.com', '01/01/1981');
        Patient__c updatedSubscriber = [SELECT Eligibility_Status__c, Member_Health_Plan__c FROM Patient__c WHERE Id = :testSubscriber.Id];
        updatedSubscriber.Eligibility_Status__c = 'Active';
        updatedSubscriber.Member_Health_Plan__c = mphName.Name;
        update updatedSubscriber;
        
        Patient__c testPatient = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Test', 'EnrollmentUser', 'Test.EnrollmentUser@progyny.com', '01/01/1980');
        
        Patient__c updatePatientSubscriberLink = [SELECT Id, Primary_Subscriber__c, Relation_to_Primary_Subscriber__c, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatient.Id];
        updatePatientSubscriberLink.Primary_Subscriber__c = testSubscriber.Id;
        updatePatientSubscriberLink.Relation_to_Primary_Subscriber__c = 'Dependent';
        updatePatientSubscriberLink.Member_Health_Plan__c = mphName.Name;
        update updatePatientSubscriberLink;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"pregnancy","Medical_History__c" : "Oncofertility;Gender Reaffirming Surgery","Previous_Treatments__c":"IUI;IVF Fresh", "Preferred_timeline_for_initial_consult__c" : "As soon as possible","Preconception_Goals__c": "Less than 6 months","Estimated_Due_Date__c":"2025-01-01","Delivery_Date__c":"2025-01-01","What_support_is_the_member_looking_for__c" : "I\'m interested in nutrition and lifestyle support"}]}';

        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assert(RestContext.response.statusCode == 500);
    }
    
    static testMethod void testEnrollMemberPostpartumSubscriber() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];

        Patient__c testSubscriber = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Subscriber', 'EnrollmentUser', 'Subscriber.EnrollmentUser@progyny.com', '01/01/1981');
        Patient__c updatedSubscriber = [SELECT Eligibility_Status__c, Member_Health_Plan__c FROM Patient__c WHERE Id = :testSubscriber.Id];
        updatedSubscriber.Eligibility_Status__c = 'Active';
        updatedSubscriber.Member_Health_Plan__c = mphName.Name;
        update updatedSubscriber;
        
        Patient__c testPatient = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Test', 'EnrollmentUser', 'Test.EnrollmentUser@progyny.com', '01/01/1980');
        
        Patient__c updatePatientSubscriberLink = [SELECT Id, Primary_Subscriber__c, Relation_to_Primary_Subscriber__c, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatient.Id];
        updatePatientSubscriberLink.Primary_Subscriber__c = testSubscriber.Id;
        updatePatientSubscriberLink.Relation_to_Primary_Subscriber__c = 'Dependent';
        updatePatientSubscriberLink.Member_Health_Plan__c = mphName.Name;
        update updatePatientSubscriberLink;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"postpartum","Medical_History__c" : "Oncofertility;Gender Reaffirming Surgery","Previous_Treatments__c":"IUI;IVF Fresh", "Preferred_timeline_for_initial_consult__c" : "As soon as possible","Preconception_Goals__c": "Less than 6 months","Estimated_Due_Date__c":"2025-01-01","Delivery_Date__c":"2025-01-01","What_support_is_the_member_looking_for__c" : "I\'m interested in nutrition and lifestyle support"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assert(RestContext.response.statusCode == 500);
    }
    
    static testMethod void testEnrollMemberMenopauseSubscriber() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];

        Patient__c testSubscriber = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Subscriber', 'EnrollmentUser', 'Subscriber.EnrollmentUser@progyny.com', '01/01/1981');
        Patient__c updatedSubscriber = [SELECT Eligibility_Status__c, Member_Health_Plan__c FROM Patient__c WHERE Id = :testSubscriber.Id];
        updatedSubscriber.Eligibility_Status__c = 'Active';
        updatedSubscriber.Member_Health_Plan__c = mphName.Name;
        update updatedSubscriber;
        
        Patient__c testPatient = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Test', 'EnrollmentUser', 'Test.EnrollmentUser@progyny.com', '01/01/1980');
        
        Patient__c updatePatientSubscriberLink = [SELECT Id, Primary_Subscriber__c, Relation_to_Primary_Subscriber__c, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatient.Id];
        updatePatientSubscriberLink.Primary_Subscriber__c = testSubscriber.Id;
        updatePatientSubscriberLink.Relation_to_Primary_Subscriber__c = 'Dependent';
        updatePatientSubscriberLink.Member_Health_Plan__c = mphName.Name;
        update updatePatientSubscriberLink;

        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"menopause","Medical_History__c" : "Oncofertility;Gender Reaffirming Surgery","Previous_Treatments__c":"IUI;IVF Fresh", "Preferred_timeline_for_initial_consult__c" : "As soon as possible","Preconception_Goals__c": "Less than 6 months","Estimated_Due_Date__c":"2025-01-01","Delivery_Date__c":"2025-01-01","What_support_is_the_member_looking_for__c" : "I\'m interested in nutrition and lifestyle support"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assert(RestContext.response.statusCode == 500);
    }
    
    static testMethod void testEnrollLBNSubscriber() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];

        Patient__c testSubscriber = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Subscriber', 'EnrollmentUser', 'Subscriber.EnrollmentUser@progyny.com', '01/01/1981');
        Patient__c updatedSubscriber = [SELECT Eligibility_Status__c, Member_Health_Plan__c FROM Patient__c WHERE Id = :testSubscriber.Id];
        updatedSubscriber.Eligibility_Status__c = 'Active';
        updatedSubscriber.Member_Health_Plan__c = mphName.Name;
        update updatedSubscriber;
        
        Patient__c testPatient = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Test', 'EnrollmentUser', 'Test.EnrollmentUser@progyny.com', '01/01/1980');
        
        Patient__c updatePatientSubscriberLink = [SELECT Id, Primary_Subscriber__c, Relation_to_Primary_Subscriber__c, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatient.Id];
        updatePatientSubscriberLink.Primary_Subscriber__c = testSubscriber.Id;
        updatePatientSubscriberLink.Relation_to_Primary_Subscriber__c = 'Dependent';
        updatePatientSubscriberLink.Member_Health_Plan__c = mphName.Name;
        update updatePatientSubscriberLink;

        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"benefits_navigation"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assert(RestContext.response.statusCode == 500);
    }

    static testMethod void testEnrollMemberCarrierExisting() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        ProgynyCarrierHelper.runCarrierTrigger = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'EnrollmentUser', 'Test.EnrollmentUser@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;        
        
        Date startDt = System.today().addDays(-30);
        Date endDt = System.today().addDays(180);
        Id testCarrierId = ProgynyTestDataFactory.setupCarrierRecord(testPatientId, memberHealthPlanId, 'Individual', 'SUBSCRIBER', String.valueOf(System.Today().Year() - 1), startDt, endDt);
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"fertility","Medical_History__c" : "Oncofertility;Gender Reaffirming Surgery","Previous_Treatments__c":"IUI;IVF Fresh", "Preferred_timeline_for_initial_consult__c" : "As soon as possible","Preconception_Goals__c": "Less than 6 months","Estimated_Due_Date__c":"2025-01-01","Delivery_Date__c":"2025-01-01","What_support_is_the_member_looking_for__c" : "I\'m interested in nutrition and lifestyle support"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assert(RestContext.response.statusCode == 200);
    }
    
    static testMethod void testEnrollMemberCarrierExistingPriorYear() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        ProgynyCarrierHelper.runCarrierTrigger = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'EnrollmentUser', 'Test.EnrollmentUser@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;        
        
        Date startDt = System.today().addDays(-30);
        Date endDt = System.today().addDays(180);
        Id testCarrierId = ProgynyTestDataFactory.setupCarrierRecord(testPatientId, memberHealthPlanId, 'Individual', 'SUBSCRIBER', String.valueOf(System.Today().Year() - 1), startDt, endDt);
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"fertility","Medical_History__c" : "Oncofertility;Gender Reaffirming Surgery","Previous_Treatments__c":"IUI;IVF Fresh", "Preferred_timeline_for_initial_consult__c" : "As soon as possible","Preconception_Goals__c": "Less than 6 months","Estimated_Due_Date__c":"2025-01-01","Delivery_Date__c":"2025-01-01","What_support_is_the_member_looking_for__c" : "I\'m interested in nutrition and lifestyle support"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assert(RestContext.response.statusCode == 200);
    }

    static testMethod void testEnrollMemberCreatesLinkedSubscriberCarrier() {
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        ProgynyCarrierHelper.runCarrierTrigger = false;
        ProgynyCarrierHelper.runCarrierAfterInsertAndUpdate = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        String planYear = [SELECT Plan_Year__c FROM Benefit_Order__c WHERE Id = :benefitOrderId].Plan_Year__c;
        
        Patient__c testSubscriber = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Subscriber', 'LinkedCarrierSub', 'Subscriber.LinkedCarrierSub@progyny.com', '01/01/1981');
        testSubscriber = [
            SELECT Id,
                   RecordTypeId,
                   Eligibility_Status__c,
                   Member_Health_Plan__c,
                   Relation_to_Primary_Subscriber__c,
                   Carrier_Member_ID__c
            FROM Patient__c
            WHERE Id = :testSubscriber.Id
        ];
        testSubscriber.RecordTypeId = Schema.SObjectType.Patient__c.getRecordTypeInfosByName().get('Enterprise').getRecordTypeId();
        testSubscriber.Eligibility_Status__c = 'Active';
        testSubscriber.Member_Health_Plan__c = mphName.Name;
        testSubscriber.Relation_to_Primary_Subscriber__c = 'Subscriber';
        testSubscriber.Carrier_Member_ID__c = 'SUBCARRIER123';
        update testSubscriber;
        
        Patient__c testPatient = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Dependent', 'LinkedCarrierDep', 'Dependent.LinkedCarrierDep@progyny.com', '01/01/1980');
        testPatient = [
            SELECT Id,
                   Primary_Subscriber__c,
                   Relation_to_Primary_Subscriber__c,
                   Member_Health_Plan__c,
                   Carrier_Member_ID__c
            FROM Patient__c
            WHERE Id = :testPatient.Id
        ];
        testPatient.Primary_Subscriber__c = testSubscriber.Id;
        testPatient.Relation_to_Primary_Subscriber__c = 'Dependent';
        testPatient.Member_Health_Plan__c = mphName.Name;
        testPatient.Carrier_Member_ID__c = 'DEPCARRIER123';
        update testPatient;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"fertility","Medical_History__c" : "Oncofertility","Previous_Treatments__c":"IUI","Preferred_timeline_for_initial_consult__c" : "As soon as possible","Preconception_Goals__c": "Less than 6 months","Estimated_Due_Date__c":"2025-01-01","Delivery_Date__c":"2025-01-01","What_support_is_the_member_looking_for__c" : "I\'m interested in nutrition and lifestyle support"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        Test.startTest();
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assertEquals(200, RestContext.response.statusCode);
        
        List<Carrier__c> linkedSubscriberCarriers = [
            SELECT Id,
                   Patient__c,
                   Plan_Year__c,
                   Member_Health_Plan__c,
                   Carrier_Member_Id__c,
                   Relation_to_Primary_Subscriber__c,
                   Plan_Type__c
            FROM Carrier__c
            WHERE Patient__c = :testSubscriber.Id
            AND Plan_Year__c = :planYear
        ];
        
        //System.assertEquals(1, linkedSubscriberCarriers.size());
        //System.assertEquals(memberHealthPlanId, linkedSubscriberCarriers[0].Member_Health_Plan__c);
        //System.assertEquals('SUBCARRIER123', linkedSubscriberCarriers[0].Carrier_Member_Id__c);
        //System.assertEquals('SUBSCRIBER', linkedSubscriberCarriers[0].Relation_to_Primary_Subscriber__c);
    }

    static testMethod void testEnrollMemberFertilitySupport() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        // Create Fertility Support Benefit Product
        Id fertilitySupportRTId = Schema.SObjectType.Benefit_Product__c.getRecordTypeInfosByName().get('Fertility Support').getRecordTypeId();
        Benefit_Product__c bp = new Benefit_Product__c(
            Benefit_Order__c = benefitOrderId,
            RecordTypeId = fertilitySupportRTId
        );
        insert bp;
        
        // Create Member Product
        Member_Product__c mp = new Member_Product__c(
            Benefit_Product__c = bp.Id,
            Member_Health_Plan__c = memberHealthPlanId
        );
        insert mp;
        
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'EnrollmentFertilitySupport', 'Test.EnrollmentFertilitySupport@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"fertility","Medical_History__c" : "Oncofertility;Gender Reaffirming Surgery","Previous_Treatments__c":"IUI;IVF Fresh", "Preferred_timeline_for_initial_consult__c" : "As soon as possible","Preconception_Goals__c": "Less than 6 months","Estimated_Due_Date__c":"2025-01-01","Delivery_Date__c":"2025-01-01","What_support_is_the_member_looking_for__c" : "I\'m interested in nutrition and lifestyle support"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assert(RestContext.response.statusCode == 200);
        Patient__c updatedPatient = [SELECT Fertility_Support_Eligible__c, Fertility_Support_Enrolled__c FROM Patient__c WHERE Id = :testPatientId];
        //System.assertEquals('Yes', updatedPatient.Fertility_Support_Eligible__c);
        //System.assertEquals(true, updatedPatient.Fertility_Support_Enrolled__c);
    }

    static testMethod void testEnrollMemberPreconceptionSupport() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        // Create Fertility Support Benefit Product
        Id fertilitySupportRTId = Schema.SObjectType.Benefit_Product__c.getRecordTypeInfosByName().get('Fertility Support').getRecordTypeId();
        Benefit_Product__c bp = new Benefit_Product__c(
            Benefit_Order__c = benefitOrderId,
            RecordTypeId = fertilitySupportRTId
        );
        insert bp;
        
        // Create Member Product
        Member_Product__c mp = new Member_Product__c(
            Benefit_Product__c = bp.Id,
            Member_Health_Plan__c = memberHealthPlanId
        );
        insert mp;
        
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'EnrollmentPreconceptionSupport', 'Test.EnrollmentPreconceptionSupport@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"preconception","Preconception_Goals__c": "Less than 6 months"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assert(RestContext.response.statusCode == 200);
        Patient__c updatedPatient = [SELECT Fertility_Support_Eligible__c, Fertility_Support_Enrolled__c, Member_Journey_Cohort__c, Preconception_Enrolled__c FROM Patient__c WHERE Id = :testPatientId];
        System.assertEquals('Yes', updatedPatient.Fertility_Support_Eligible__c);
        System.assertEquals(true, updatedPatient.Fertility_Support_Enrolled__c);
        System.assertEquals('Preconception Support', updatedPatient.Member_Journey_Cohort__c);
        System.assertEquals(true, updatedPatient.Preconception_Enrolled__c);
    }

    static testMethod void testEnrollMemberAdoptionSupport() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        // Create Fertility Support Benefit Product
        Id fertilitySupportRTId = Schema.SObjectType.Benefit_Product__c.getRecordTypeInfosByName().get('Fertility Support').getRecordTypeId();
        Benefit_Product__c bp = new Benefit_Product__c(
            Benefit_Order__c = benefitOrderId,
            RecordTypeId = fertilitySupportRTId
        );
        insert bp;
        
        // Create Member Product
        Member_Product__c mp = new Member_Product__c(
            Benefit_Product__c = bp.Id,
            Member_Health_Plan__c = memberHealthPlanId
        );
        insert mp;
        
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'EnrollmentAdoptionSupport', 'Test.EnrollmentAdoptionSupport@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"adoption"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assert(RestContext.response.statusCode == 200);
        Patient__c updatedPatient = [SELECT Fertility_Support_Eligible__c, Fertility_Support_Enrolled__c, Member_Journey_Cohort__c FROM Patient__c WHERE Id = :testPatientId];
    }

    static testMethod void testEnrollMemberSurrogacySupport() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        // Create Fertility Support Benefit Product
        Id fertilitySupportRTId = Schema.SObjectType.Benefit_Product__c.getRecordTypeInfosByName().get('Fertility Support').getRecordTypeId();
        Benefit_Product__c bp = new Benefit_Product__c(
            Benefit_Order__c = benefitOrderId,
            RecordTypeId = fertilitySupportRTId
        );
        insert bp;
        
        // Create Member Product
        Member_Product__c mp = new Member_Product__c(
            Benefit_Product__c = bp.Id,
            Member_Health_Plan__c = memberHealthPlanId
        );
        insert mp;
        
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'EnrollmentSurrogacySupport', 'Test.EnrollmentSurrogacySupport@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"surrogacy"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assert(RestContext.response.statusCode == 200);
        Patient__c updatedPatient = [SELECT Fertility_Support_Eligible__c, Fertility_Support_Enrolled__c, Member_Journey_Cohort__c FROM Patient__c WHERE Id = :testPatientId];
    }

    static testMethod void testEnrollMemberPregnancySupport() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        // Create Fertility Support Benefit Product
        Id fertilitySupportRTId = Schema.SObjectType.Benefit_Product__c.getRecordTypeInfosByName().get('Fertility Support').getRecordTypeId();
        Benefit_Product__c bp = new Benefit_Product__c(
            Benefit_Order__c = benefitOrderId,
            RecordTypeId = fertilitySupportRTId
        );
        insert bp;
        
        // Create Member Product
        Member_Product__c mp = new Member_Product__c(
            Benefit_Product__c = bp.Id,
            Member_Health_Plan__c = memberHealthPlanId
        );
        insert mp;
        
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'EnrollmentPregnancySupport', 'Test.EnrollmentPregnancySupport@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"pregnancy","Estimated_Due_Date__c":"2025-01-01"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        //System.assert(RestContext.response.statusCode == 200);
        Patient__c updatedPatient = [SELECT Pregnancy_Postpartum_Enrolled__c, Member_Journey_Cohort__c, Fertility_Support_Enrolled__c FROM Patient__c WHERE Id = :testPatientId];
    }

    static testMethod void testEnrollMemberPostpartumSupport() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        // Create Fertility Support Benefit Product
        Id fertilitySupportRTId = Schema.SObjectType.Benefit_Product__c.getRecordTypeInfosByName().get('Fertility Support').getRecordTypeId();
        Benefit_Product__c bp = new Benefit_Product__c(
            Benefit_Order__c = benefitOrderId,
            RecordTypeId = fertilitySupportRTId
        );
        insert bp;
        
        // Create Member Product
        Member_Product__c mp = new Member_Product__c(
            Benefit_Product__c = bp.Id,
            Member_Health_Plan__c = memberHealthPlanId
        );
        insert mp;
        
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'EnrollmentPostpartumSupport', 'Test.EnrollmentPostpartumSupport@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"postpartum","Estimated_Due_Date__c":"2025-01-01"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        //System.assert(RestContext.response.statusCode == 200);
        Patient__c updatedPatient = [SELECT Pregnancy_Postpartum_Enrolled__c, Member_Journey_Cohort__c, Fertility_Support_Enrolled__c FROM Patient__c WHERE Id = :testPatientId];
    }

    static testMethod void testEnrollMemberMenopauseSupport() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        // Create Fertility Support Benefit Product
        Id fertilitySupportRTId = Schema.SObjectType.Benefit_Product__c.getRecordTypeInfosByName().get('Fertility Support').getRecordTypeId();
        Benefit_Product__c bp = new Benefit_Product__c(
            Benefit_Order__c = benefitOrderId,
            RecordTypeId = fertilitySupportRTId
        );
        insert bp;
        
        // Create Member Product
        Member_Product__c mp = new Member_Product__c(
            Benefit_Product__c = bp.Id,
            Member_Health_Plan__c = memberHealthPlanId
        );
        insert mp;
        
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'EnrollmentMenopauseSupport', 'Test.EnrollmentMenopauseSupport@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"menopause","What_support_is_the_member_looking_for__c" : "I\'m interested in nutrition and lifestyle support"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
       // System.assert(RestContext.response.statusCode == 200);
        Patient__c updatedPatient = [SELECT Progyny_Menopause_Enrolled__c, Member_Journey_Cohort__c, Fertility_Support_Enrolled__c FROM Patient__c WHERE Id = :testPatientId];
    }

    static testMethod void testEnrollMemberParentingSupport() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        // Create Fertility Support Benefit Product
        Id fertilitySupportRTId = Schema.SObjectType.Benefit_Product__c.getRecordTypeInfosByName().get('Fertility Support').getRecordTypeId();
        Benefit_Product__c bp = new Benefit_Product__c(
            Benefit_Order__c = benefitOrderId,
            RecordTypeId = fertilitySupportRTId
        );
        insert bp;
        
        // Create Member Product
        Member_Product__c mp = new Member_Product__c(
            Benefit_Product__c = bp.Id,
            Member_Health_Plan__c = memberHealthPlanId
        );
        insert mp;
        
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'EnrollmentParentingSupport', 'Test.EnrollmentParentingSupport@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"parenting","Children__c": [{"first_name": "Andy","date_of_birth": "1995-05-04"}]}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        //System.assert(RestContext.response.statusCode == 200);
        Patient__c updatedPatient = [SELECT Parent_Child_Well_being_Enrolled__c, Member_Journey_Cohort__c, Fertility_Support_Enrolled__c FROM Patient__c WHERE Id = :testPatientId];
     
    }

    static testMethod void testEnrollMemberPregnancySupportSubscriber() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        // Create Fertility Support Benefit Product
        Id fertilitySupportRTId = Schema.SObjectType.Benefit_Product__c.getRecordTypeInfosByName().get('Fertility Support').getRecordTypeId();
        Benefit_Product__c bp = new Benefit_Product__c(
            Benefit_Order__c = benefitOrderId,
            RecordTypeId = fertilitySupportRTId
        );
        insert bp;
        
        // Create Member Product
        Member_Product__c mp = new Member_Product__c(
            Benefit_Product__c = bp.Id,
            Member_Health_Plan__c = memberHealthPlanId
        );
        insert mp;

        Patient__c testSubscriber = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Subscriber', 'EnrollmentPregnancySub', 'Subscriber.EnrollmentPregnancySub@progyny.com', '01/01/1981');
        Patient__c updatedSubscriber = [SELECT Eligibility_Status__c, Member_Health_Plan__c FROM Patient__c WHERE Id = :testSubscriber.Id];
        updatedSubscriber.Eligibility_Status__c = 'Active';
        updatedSubscriber.Member_Health_Plan__c = mphName.Name;
        update updatedSubscriber;
        
        Patient__c testPatient = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Test', 'EnrollmentPregnancyDep', 'Test.EnrollmentPregnancyDep@progyny.com', '01/01/1980');
        
        Patient__c updatePatientSubscriberLink = [SELECT Id, Primary_Subscriber__c, Relation_to_Primary_Subscriber__c, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatient.Id];
        updatePatientSubscriberLink.Primary_Subscriber__c = testSubscriber.Id;
        updatePatientSubscriberLink.Relation_to_Primary_Subscriber__c = 'Dependent';
        updatePatientSubscriberLink.Member_Health_Plan__c = mphName.Name;
        update updatePatientSubscriberLink;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"pregnancy","Estimated_Due_Date__c":"2025-01-01"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assert(RestContext.response.statusCode == 500);
    }

    static testMethod void testEnrollMemberPostpartumSupportSubscriber() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        // Create Fertility Support Benefit Product
        Id fertilitySupportRTId = Schema.SObjectType.Benefit_Product__c.getRecordTypeInfosByName().get('Fertility Support').getRecordTypeId();
        Benefit_Product__c bp = new Benefit_Product__c(
            Benefit_Order__c = benefitOrderId,
            RecordTypeId = fertilitySupportRTId
        );
        insert bp;
        
        // Create Member Product
        Member_Product__c mp = new Member_Product__c(
            Benefit_Product__c = bp.Id,
            Member_Health_Plan__c = memberHealthPlanId
        );
        insert mp;

        Patient__c testSubscriber = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Subscriber', 'EnrollmentPostpartumSub', 'Subscriber.EnrollmentPostpartumSub@progyny.com', '01/01/1981');
        Patient__c updatedSubscriber = [SELECT Eligibility_Status__c, Member_Health_Plan__c FROM Patient__c WHERE Id = :testSubscriber.Id];
        updatedSubscriber.Eligibility_Status__c = 'Active';
        updatedSubscriber.Member_Health_Plan__c = mphName.Name;
        update updatedSubscriber;
        
        Patient__c testPatient = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Test', 'EnrollmentPostpartumDep', 'Test.EnrollmentPostpartumDep@progyny.com', '01/01/1980');
        
        Patient__c updatePatientSubscriberLink = [SELECT Id, Primary_Subscriber__c, Relation_to_Primary_Subscriber__c, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatient.Id];
        updatePatientSubscriberLink.Primary_Subscriber__c = testSubscriber.Id;
        updatePatientSubscriberLink.Relation_to_Primary_Subscriber__c = 'Dependent';
        updatePatientSubscriberLink.Member_Health_Plan__c = mphName.Name;
        update updatePatientSubscriberLink;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"postpartum","Estimated_Due_Date__c":"2025-01-01"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assert(RestContext.response.statusCode == 500);
    }

    static testMethod void testEnrollMemberMenopauseSupportSubscriber() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        // Create Fertility Support Benefit Product
        Id fertilitySupportRTId = Schema.SObjectType.Benefit_Product__c.getRecordTypeInfosByName().get('Fertility Support').getRecordTypeId();
        Benefit_Product__c bp = new Benefit_Product__c(
            Benefit_Order__c = benefitOrderId,
            RecordTypeId = fertilitySupportRTId
        );
        insert bp;
        
        // Create Member Product
        Member_Product__c mp = new Member_Product__c(
            Benefit_Product__c = bp.Id,
            Member_Health_Plan__c = memberHealthPlanId
        );
        insert mp;

        Patient__c testSubscriber = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Subscriber', 'EnrollmentMenopauseSub', 'Subscriber.EnrollmentMenopauseSub@progyny.com', '01/01/1981');
        Patient__c updatedSubscriber = [SELECT Eligibility_Status__c, Member_Health_Plan__c FROM Patient__c WHERE Id = :testSubscriber.Id];
        updatedSubscriber.Eligibility_Status__c = 'Active';
        updatedSubscriber.Member_Health_Plan__c = mphName.Name;
        update updatedSubscriber;
        
        Patient__c testPatient = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Test', 'EnrollmentMenopauseDep', 'Test.EnrollmentMenopauseDep@progyny.com', '01/01/1980');
        
        Patient__c updatePatientSubscriberLink = [SELECT Id, Primary_Subscriber__c, Relation_to_Primary_Subscriber__c, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatient.Id];
        updatePatientSubscriberLink.Primary_Subscriber__c = testSubscriber.Id;
        updatePatientSubscriberLink.Relation_to_Primary_Subscriber__c = 'Dependent';
        updatePatientSubscriberLink.Member_Health_Plan__c = mphName.Name;
        update updatePatientSubscriberLink;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"menopause","What_support_is_the_member_looking_for__c" : "I\'m interested in nutrition and lifestyle support"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assert(RestContext.response.statusCode == 500);
    }

    static testMethod void testEnrollMemberParentingSupportSubscriber() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        // Create Fertility Support Benefit Product
        Id fertilitySupportRTId = Schema.SObjectType.Benefit_Product__c.getRecordTypeInfosByName().get('Fertility Support').getRecordTypeId();
        Benefit_Product__c bp = new Benefit_Product__c(
            Benefit_Order__c = benefitOrderId,
            RecordTypeId = fertilitySupportRTId
        );
        insert bp;
        
        // Create Member Product
        Member_Product__c mp = new Member_Product__c(
            Benefit_Product__c = bp.Id,
            Member_Health_Plan__c = memberHealthPlanId
        );
        insert mp;

        Patient__c testSubscriber = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Subscriber', 'EnrollmentParentingSub', 'Subscriber.EnrollmentParentingSub@progyny.com', '01/01/1981');
        Patient__c updatedSubscriber = [SELECT Eligibility_Status__c, Member_Health_Plan__c FROM Patient__c WHERE Id = :testSubscriber.Id];
        updatedSubscriber.Eligibility_Status__c = 'Active';
        updatedSubscriber.Member_Health_Plan__c = mphName.Name;
        update updatedSubscriber;
        
        Patient__c testPatient = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Test', 'EnrollmentParentingDep', 'Test.EnrollmentParentingDep@progyny.com', '01/01/1980');
        
        Patient__c updatePatientSubscriberLink = [SELECT Id, Primary_Subscriber__c, Relation_to_Primary_Subscriber__c, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatient.Id];
        updatePatientSubscriberLink.Primary_Subscriber__c = testSubscriber.Id;
        updatePatientSubscriberLink.Relation_to_Primary_Subscriber__c = 'Dependent';
        updatePatientSubscriberLink.Member_Health_Plan__c = mphName.Name;
        update updatePatientSubscriberLink;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"parenting","Children__c": [{"first_name": "Andy","date_of_birth": "1995-05-04"}]}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assert(RestContext.response.statusCode == 500);
    }

    static testMethod void testEnrollMemberNoActiveBenefitOrder() {
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;

        Id accountWithoutBenefitOrderId = ProgynyTestDataFactory.setupProgynyEnterpriseAccount('Enrollment Account No BO');
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(accountWithoutBenefitOrderId, 'Test', 'NoBenefitOrder', 'Test.NoBenefitOrder@progyny.com', '01/01/1980');

        setupRestRequest(fertilityRequestBody(testPatientId));

        Test.startTest();
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode);
        System.assertEquals('There is no active benefit order related to the patient\'s account', RestContext.response.responseBody.toString());
    }

    static testMethod void testEnrollMemberDependentInactiveSubscriber() {
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;

        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];

        Patient__c testSubscriber = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Inactive', 'Subscriber', 'Inactive.Subscriber@progyny.com', '01/01/1981');
        Patient__c testPatient = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Dependent', 'InactiveSub', 'Dependent.InactiveSub@progyny.com', '01/01/1980');
        testPatient = [SELECT Id, Primary_Subscriber__c, Relation_to_Primary_Subscriber__c, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatient.Id];
        testPatient.Primary_Subscriber__c = testSubscriber.Id;
        testPatient.Relation_to_Primary_Subscriber__c = 'Dependent';
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;

        setupRestRequest(fertilityRequestBody(testPatient.Id));

        Test.startTest();
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();

        System.assertEquals(500, RestContext.response.statusCode);
        System.assertEquals('The dependent\'s primary subscriber does not have an active eligiblity status', RestContext.response.responseBody.toString());
    }

    static testMethod void testEnrollMemberMockModeSkipsCarrierCreation() {
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;

        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];

        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'MockMode', 'Test.MockMode@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;

        String requestBody = '{"Mock_Mode":"true","enrollment":[{"Id":"' + testPatient.Id + '","Product":"fertility","Medical_History__c" : "Oncofertility","Previous_Treatments__c":"IUI","Preferred_timeline_for_initial_consult__c" : "As soon as possible"}]}';
        setupRestRequest(requestBody);

        Test.startTest();
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals(0, [SELECT COUNT() FROM Carrier__c WHERE Patient__c = :testPatient.Id]);
    }

    static testMethod void testEnrollMemberAppliesVipMemberFromBenefitOrder() {
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;

        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Benefit_Order__c benefitOrder = [SELECT Id, VIP_Member__c FROM Benefit_Order__c WHERE Account__c = :testAccountId];
        benefitOrder.VIP_Member__c = true;
        update benefitOrder;

        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrder.Id].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];

        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'VipMember', 'Test.VipMember@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;

        setupRestRequest(fertilityRequestBody(testPatient.Id));

        Test.startTest();
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals(true, [SELECT VIP_Member__c FROM Patient__c WHERE Id = :testPatient.Id].VIP_Member__c);
    }

    static testMethod void testEnrollMemberFertilitySupportWithFapProduct() {
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;

        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        createFertilitySupportBenefit(benefitOrderId, memberHealthPlanId, true);

        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'FapSupport', 'Test.FapSupport@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;

        setupRestRequest(fertilityRequestBody(testPatient.Id));

        Test.startTest();
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();

        Patient__c updatedPatient = [SELECT Fertility_FAP_Enrolled__c, Fertility_Support_Enrolled__c, Member_Journey_Cohort__c FROM Patient__c WHERE Id = :testPatient.Id];
        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals(true, updatedPatient.Fertility_FAP_Enrolled__c);
        System.assertEquals(true, updatedPatient.Fertility_Support_Enrolled__c);
        System.assertEquals('Fertility Support', updatedPatient.Member_Journey_Cohort__c);
    }

    static testMethod void testEnrollMemberUpdatesOverlappingCarrierWithoutPlanYear() {
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg  = false;
        ProgynyCarrierHelper.runCarrierTrigger = false;

        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Benefit_Order__c benefitOrder = [SELECT Id, Plan_Year__c FROM Benefit_Order__c WHERE Id = :benefitOrderId];
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];

        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'NoPlanYearCarrier', 'Test.NoPlanYearCarrier@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;

        Id carrierWithoutPlanYearId = ProgynyTestDataFactory.setupCarrierRecord(testPatient.Id, memberHealthPlanId, 'Individual', 'SUBSCRIBER', null, System.today(), System.today().addDays(10));
        setupRestRequest(fertilityRequestBody(testPatient.Id));

        Test.startTest();
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();

        Carrier__c updatedCarrier = [SELECT Id, Plan_Year__c, Member_Health_Plan__c FROM Carrier__c WHERE Id = :carrierWithoutPlanYearId];
        //System.assertEquals(200, RestContext.response.statusCode);
        //System.assertEquals(benefitOrder.Plan_Year__c, updatedCarrier.Plan_Year__c);
        //System.assertEquals(memberHealthPlanId, updatedCarrier.Member_Health_Plan__c);
        //System.assertEquals(1, [SELECT COUNT() FROM Carrier__c WHERE Patient__c = :testPatient.Id]);
    }
    
    //trtest start
    @IsTest
    static void testGetCarrierRelationToSubscriber_NullPatient() {
        Test.startTest();
    
        String result = DOEnrollmentRestService.getCarrierRelationToSubscriber(null);
    
        Test.stopTest();
    
    }
    @IsTest
    static void testGetCarrierRelationToSubscriber_BlankRelation() {
        Patient__c patient = new Patient__c();
        patient.Relation_to_Primary_Subscriber__c = null;
    
        Test.startTest();
    
        String result =
            DOEnrollmentRestService.getCarrierRelationToSubscriber(patient);
    
        Test.stopTest();
    
        
    }
    @IsTest
    static void testGetCarrierRelationToSubscriber_Subscriber() {
        Patient__c patient = new Patient__c();
        patient.Relation_to_Primary_Subscriber__c = 'Subscriber';
    
        Test.startTest();
    
        String result =
            DOEnrollmentRestService.getCarrierRelationToSubscriber(patient);
    
        Test.stopTest();
    
        
    }
    @IsTest
    static void testGetCarrierRelationToSubscriber_UpperCaseSubscriber() {
        Patient__c patient = new Patient__c();
        patient.Relation_to_Primary_Subscriber__c = 'SUBSCRIBER';
    
        Test.startTest();
    
        String result =
            DOEnrollmentRestService.getCarrierRelationToSubscriber(patient);
    
        Test.stopTest();
    
        
    }
    //trtest end
}
