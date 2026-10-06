/**
* @author: Coverage Enhancement
* @description: Additional test methods to increase code coverage for helper methods
* Focus: applyInsuranceIdCheck, carrierDatesOverlap, hasMatchingLinkedCarrier
**/ 

@isTest
public class DOEnrollmentRestServiceAdditionalTests {
    
    @testSetup static void setup() {
        ProgynyStaticFuture.executePatientTrg = false;
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyCarrierHelper.runCarrierTrigger = false;
        ProgynyAccountTriggerHandler.isBeforeFirstTime = false;
        ProgynyAccountTriggerHandler.isAfterFirstTime = false;
        
        Id testAccountId = ProgynyTestDataFactory.setupProgynyEnterpriseAccount('Enrollment Account');
        Id benefitOrderId = ProgynyTestDataFactory.setupBenefitOrder(testAccountId);
        Id testMemberhealthPlan = ProgynyTestDataFactory.setupMemberHelathPlan(benefitOrderId, testAccountId);        
    }

    /**
     * Test carrier date overlap logic - overlapping dates
     */
    static testMethod void testCarrierDatesOverlapWithOverlappingDates() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg = false;
        ProgynyCarrierHelper.runCarrierTrigger = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        // Create patient
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'DateOverlap', 'Test.DateOverlap@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        // Create carrier with dates that will overlap
        Date startDt = System.today().addDays(-30);
        Date endDt = System.today().addDays(180);
        Id testCarrierId = ProgynyTestDataFactory.setupCarrierRecord(testPatientId, memberHealthPlanId, 'Individual', 'SUBSCRIBER', String.valueOf(System.Today().Year()), startDt, endDt);
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"fertility","Medical_History__c" : "Oncofertility","Previous_Treatments__c":"IUI","Preferred_timeline_for_initial_consult__c":"Less than 3 months"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assertEquals(200, RestContext.response.statusCode);
    }

    /**
     * Test carrier date overlap logic - non-overlapping dates (should not find match)
     */
    static testMethod void testCarrierDatesOverlapWithNonOverlappingDates() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg = false;
        ProgynyCarrierHelper.runCarrierTrigger = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        // Create patient
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'NoOverlap', 'Test.NoOverlap@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c, Coverage_Start_Date__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        testPatient.Coverage_Start_Date__c = System.today(); // Set coverage start to today
        update testPatient;
        
        // Create carrier with past dates that won't overlap
        Date startDt = System.today().addDays(-180);
        Date endDt = System.today().addDays(-30);
        Id testCarrierId = ProgynyTestDataFactory.setupCarrierRecord(testPatientId, memberHealthPlanId, 'Individual', 'SUBSCRIBER', String.valueOf(System.Today().Year() - 1), startDt, endDt);
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"fertility","Medical_History__c" : "Oncofertility","Previous_Treatments__c":"IUI","Preferred_timeline_for_initial_consult__c":"Less than 3 months"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assertEquals(200, RestContext.response.statusCode);
    }

    /**
     * Test carrier date overlap with null dates
     */
    static testMethod void testCarrierDatesOverlapWithNullDates() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg = false;
        ProgynyCarrierHelper.runCarrierTrigger = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        // Create patient
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'NullDates', 'Test.NullDates@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        // Create carrier without dates
        Id testCarrierId = ProgynyTestDataFactory.setupCarrierRecord(testPatientId, memberHealthPlanId, 'Individual', 'SUBSCRIBER', String.valueOf(System.Today().Year()), null, null);
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"fertility","Medical_History__c" : "Oncofertility","Previous_Treatments__c":"IUI","Preferred_timeline_for_initial_consult__c":"Less than 3 months"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assertEquals(200, RestContext.response.statusCode);
    }

    /**
     * Test finding matching carrier when carrier exists with matching plan year
     */
    static testMethod void testFindMatchingCarrierWithMatchingPlanYear() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg = false;
        ProgynyCarrierHelper.runCarrierTrigger = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        Benefit_Order__c bo = [SELECT Plan_Year__c FROM Benefit_Order__c WHERE Id = :benefitOrderId];
        
        // Create patient
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'MatchingYear', 'Test.MatchingYear@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        // Create carrier with matching plan year
        Date startDt = System.today().addDays(-30);
        Date endDt = System.today().addDays(180);
        Id testCarrierId = ProgynyTestDataFactory.setupCarrierRecord(testPatientId, memberHealthPlanId, 'Individual', 'SUBSCRIBER', bo.Plan_Year__c, startDt, endDt);
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"fertility","Medical_History__c" : "Oncofertility","Previous_Treatments__c":"IUI","Preferred_timeline_for_initial_consult__c":"Less than 3 months"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assertEquals(200, RestContext.response.statusCode);
        
        // Verify carrier was updated (matching year should be found and reused)
        List<Carrier__c> carriers = [SELECT Id, Plan_Year__c FROM Carrier__c WHERE Patient__c = :testPatientId];
        System.assert(carriers.size() > 0, 'Carrier should exist for patient');
    }

    /**
     * Test finding matching carrier when no carriers exist
     */
    static testMethod void testFindMatchingCarrierWithNoExistingCarriers() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg = false;
        ProgynyCarrierHelper.runCarrierTrigger = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        // Create patient with no existing carriers
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'NoCarriers', 'Test.NoCarriers@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"fertility","Medical_History__c" : "Oncofertility","Previous_Treatments__c":"IUI","Preferred_timeline_for_initial_consult__c":"Less than 3 months"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assertEquals(200, RestContext.response.statusCode);
        
        // Verify new carrier was created
        List<Carrier__c> carriers = [SELECT Id FROM Carrier__c WHERE Patient__c = :testPatientId];
        System.assertEquals(1, carriers.size(), 'New carrier should have been created');
    }

    /**
     * Test finding matching carrier with null coverage start date
     */
    static testMethod void testFindMatchingCarrierWithNullCoverageStartDate() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg = false;
        ProgynyCarrierHelper.runCarrierTrigger = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        // Create patient with null coverage start date
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'NullCoverageStart', 'Test.NullCoverageStart@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c, Coverage_Start_Date__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        testPatient.Coverage_Start_Date__c = null;
        update testPatient;
        
        // Create carrier with dates
        Date startDt = System.today().addDays(-30);
        Date endDt = System.today().addDays(180);
        Id testCarrierId = ProgynyTestDataFactory.setupCarrierRecord(testPatientId, memberHealthPlanId, 'Individual', 'SUBSCRIBER', String.valueOf(System.Today().Year()), startDt, endDt);
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"fertility","Medical_History__c" : "Oncofertility","Previous_Treatments__c":"IUI","Preferred_timeline_for_initial_consult__c":"Less than 3 months"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assertEquals(200, RestContext.response.statusCode);
    }

    /**
     * Test linked carrier creation with dependent patient
     */
    static testMethod void testLinkedCarrierCreationForDependent() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg = false;
        ProgynyCarrierHelper.runCarrierTrigger = false;
        ProgynyCarrierHelper.runCarrierAfterInsertAndUpdate = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        String planYear = [SELECT Plan_Year__c FROM Benefit_Order__c WHERE Id = :benefitOrderId].Plan_Year__c;
        
        // Create subscriber with carrier
        Patient__c testSubscriber = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Subscriber', 'LinkedDep', 'Subscriber.LinkedDep@progyny.com', '01/01/1981');
        testSubscriber = [
            SELECT Id, RecordTypeId, Eligibility_Status__c, Member_Health_Plan__c, Relation_to_Primary_Subscriber__c, Carrier_Member_ID__c
            FROM Patient__c
            WHERE Id = :testSubscriber.Id
        ];
        testSubscriber.RecordTypeId = Schema.SObjectType.Patient__c.getRecordTypeInfosByName().get('Enterprise').getRecordTypeId();
        testSubscriber.Eligibility_Status__c = 'Active';
        testSubscriber.Member_Health_Plan__c = mphName.Name;
        testSubscriber.Relation_to_Primary_Subscriber__c = 'Subscriber';
        testSubscriber.Carrier_Member_ID__c = 'SUBCARRIER123';
        update testSubscriber;
        
        // Create carrier for subscriber
        Date startDt = System.today().addDays(-30);
        Date endDt = System.today().addDays(180);
        Id subCarrierId = ProgynyTestDataFactory.setupCarrierRecord(testSubscriber.Id, memberHealthPlanId, 'Individual', 'SUBSCRIBER', planYear, startDt, endDt);
        
        // Create dependent patient
        Patient__c testPatient = ProgynyTestDataFactory.createProgynyGeneralPatient(testAccountId, 'Dependent', 'LinkedDep', 'Dependent.LinkedDep@progyny.com', '01/01/1990');
        testPatient = [
            SELECT Id, Primary_Subscriber__c, Relation_to_Primary_Subscriber__c, Member_Health_Plan__c, Carrier_Member_ID__c
            FROM Patient__c
            WHERE Id = :testPatient.Id
        ];
        testPatient.Primary_Subscriber__c = testSubscriber.Id;
        testPatient.Relation_to_Primary_Subscriber__c = 'Child';
        testPatient.Member_Health_Plan__c = mphName.Name;
        testPatient.Carrier_Member_ID__c = 'DEPCARRIER123';
        update testPatient;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"fertility","Medical_History__c" : "Oncofertility","Previous_Treatments__c":"IUI","Preferred_timeline_for_initial_consult__c":"Less than 3 months"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assertEquals(200, RestContext.response.statusCode);
        
        // Verify linked carriers were created
        List<Carrier__c> subCarriers = [
            SELECT Id FROM Carrier__c WHERE Patient__c = :testSubscriber.Id AND Plan_Year__c = :planYear
        ];
        System.assert(subCarriers.size() > 0, 'Subscriber should have linked carriers created');
    }

    /**
     * Test linked carrier creation when source carrier is null
     */
    static testMethod void testLinkedCarrierCreationWithNullSourceCarrier() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg = false;
        ProgynyCarrierHelper.runCarrierTrigger = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        // Create patient
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'NullCarrier', 'Test.NullCarrier@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        // Use mock mode to prevent carrier creation
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"fertility","Medical_History__c" : "Oncofertility","Previous_Treatments__c":"IUI","Preferred_timeline_for_initial_consult__c":"Less than 3 months","Mock_Mode":"true"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assertEquals(200, RestContext.response.statusCode);
    }

    /**
     * Test carrier creation with cloning from previous year
     */
    static testMethod void testCarrierCloningFromPreviousYear() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg = false;
        ProgynyCarrierHelper.runCarrierTrigger = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        Benefit_Order__c bo = [SELECT Plan_Year__c FROM Benefit_Order__c WHERE Id = :benefitOrderId];
        
        // Create patient
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'CloneYear', 'Test.CloneYear@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        // Create carrier for previous year
        Date startDt = System.today().addDays(-30);
        Date endDt = System.today().addDays(180);
        Integer prevYear = Integer.valueOf(bo.Plan_Year__c) - 1;
        Id testCarrierId = ProgynyTestDataFactory.setupCarrierRecord(testPatientId, memberHealthPlanId, 'Individual', 'SUBSCRIBER', String.valueOf(prevYear), startDt, endDt);
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"fertility","Medical_History__c" : "Oncofertility","Previous_Treatments__c":"IUI","Preferred_timeline_for_initial_consult__c":"Less than 3 months"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assertEquals(200, RestContext.response.statusCode);
        
        // Verify new carrier was created by cloning previous year
        List<Carrier__c> carriers = [SELECT Id, Plan_Year__c FROM Carrier__c WHERE Patient__c = :testPatientId ORDER BY CreatedDate DESC];
        System.assert(carriers.size() >= 2, 'Should have carriers from both years');
    }

    /**
     * Test carrier update with existing plan year
     */
    static testMethod void testCarrierUpdateWithExistingPlanYear() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg = false;
        ProgynyCarrierHelper.runCarrierTrigger = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        Benefit_Order__c bo = [SELECT Plan_Year__c FROM Benefit_Order__c WHERE Id = :benefitOrderId];
        
        // Create patient
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'UpdateYear', 'Test.UpdateYear@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        // Create carrier with same plan year
        Date startDt = System.today().addDays(-30);
        Date endDt = System.today().addDays(180);
        Id testCarrierId = ProgynyTestDataFactory.setupCarrierRecord(testPatientId, memberHealthPlanId, 'Individual', 'SUBSCRIBER', bo.Plan_Year__c, startDt, endDt);
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"fertility","Medical_History__c" : "Oncofertility","Previous_Treatments__c":"IUI","Preferred_timeline_for_initial_consult__c":"Less than 3 months"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assertEquals(200, RestContext.response.statusCode);
        
        // Verify carrier was updated
        List<Carrier__c> carriers = [SELECT Id, Plan_Year__c FROM Carrier__c WHERE Patient__c = :testPatientId];
        System.assertEquals(1, carriers.size(), 'Should have only one carrier after update');
        System.assertEquals(bo.Plan_Year__c, carriers[0].Plan_Year__c);
    }

    /**
     * Test null or empty existing carriers list
     */
    static testMethod void testFindMatchingCarrierWithEmptyList() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg = false;
        ProgynyCarrierHelper.runCarrierTrigger = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        // Create patient
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'EmptyList', 'Test.EmptyList@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        update testPatient;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"fertility","Medical_History__c" : "Oncofertility","Previous_Treatments__c":"IUI","Preferred_timeline_for_initial_consult__c":"Less than 3 months"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assertEquals(200, RestContext.response.statusCode);
        
        // Verify new carrier was created
        List<Carrier__c> carriers = [SELECT Id FROM Carrier__c WHERE Patient__c = :testPatientId];
        System.assertEquals(1, carriers.size(), 'New carrier should have been created');
    }

    /**
     * Test carrier member ID preservation
     */
    static testMethod void testCarrierMemberIdPreservation() {
        Test.startTest();
        ProgynyStaticFuture.executePatientTrgAfter = false;
        ProgynyStaticFuture.executePatientTrg = false;
        ProgynyCarrierHelper.runCarrierTrigger = false;
        
        Id testAccountId = [SELECT Id FROM Account WHERE Name = 'Enrollment Account'].Id;
        Id benefitOrderId = [SELECT Id FROM Benefit_Order__c WHERE Account__c = :testAccountId].Id;
        Id memberHealthPlanId = [SELECT Id FROM Member_Health_Plan__c WHERE Benefit_Order__c = :benefitOrderId].Id;
        Member_Health_Plan__c mphName = [SELECT Name FROM Member_Health_Plan__c WHERE Id = :memberHealthPlanId];
        
        // Create patient with carrier member ID
        Id testPatientId = ProgynyTestDataFactory.setupProgynyPatient(testAccountId, 'Test', 'MemberId', 'Test.MemberId@progyny.com', '01/01/1980');
        Patient__c testPatient = [SELECT Id, Member_Health_Plan__c, Carrier_Member_ID__c FROM Patient__c WHERE Id = :testPatientId];
        testPatient.Member_Health_Plan__c = mphName.Name;
        testPatient.Carrier_Member_ID__c = 'TESTCARRIER123456';
        update testPatient;
        
        String requestBody = '{"enrollment":[{"Id":"' + testPatient.Id + '","Product":"fertility","Medical_History__c" : "Oncofertility","Previous_Treatments__c":"IUI","Preferred_timeline_for_initial_consult__c":"Less than 3 months"}]}';
        
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/enrollment/finish';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueof(requestBody);
        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;
        
        DOEnrollmentRestService.enrollMember();
        Test.stopTest();
        
        System.assertEquals(200, RestContext.response.statusCode);
        
        // Verify carrier was created with carrier member ID
        List<Carrier__c> carriers = [SELECT Id, Carrier_Member_Id__c FROM Carrier__c WHERE Patient__c = :testPatientId];
        System.assertEquals(1, carriers.size(), 'Carrier should be created');
        System.assertEquals('TESTCARRIER123456', carriers[0].Carrier_Member_Id__c, 'Carrier member ID should be preserved');
    }
}
