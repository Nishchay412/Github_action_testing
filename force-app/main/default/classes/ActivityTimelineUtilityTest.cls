/***************************************************************************************
Class Name : ActivityTimelineUtilityTest
Created Date : 10-02-2024
Description : Test class for ActivityTimelineUtility

Modification Log:

* Developer Name    Date        Description
-----------------------------------------------------------------------------------------
* Jeffrey Ko        10/02/2024  WMCSFH2-4733 - New Test Class
* Jeffrey Ko        02/06/2025  WMCSFH2-5566 - Updated tests to support changes in ActivityTimelineUtility
* Jeffrey Ko        02/12/2025  WMCSFH2-5610 - Updated tests to support changes in ActivityTimelineUtility
* Jeffrey Ko        02/14/2025  WMCSFH2-5622 - Updated tests to support changes in ActivityTimelineUtility
* Prathyusha KV     05/22/2025  WMCSFH2-6109,6146 - Updated tests to support changes in ActivityTimelineUtility
* Prathyusha KV     02-06-2025  WMCSFH2-6041,6014 changes to test class
******************************************************************************************/
@isTest(seeAllData=false)
public class ActivityTimelineUtilityTest 
{
    private static final Set<String> PROFILE_NAME_SET = new Set<String>{WMC_Constants.DS_PROFILENAME, WMC_Constants.ADMIN_PROFILE};
    private static final Id EVENT_RECORD_TYPE = Schema.SObjectType.Event.getRecordTypeInfosByDeveloperName().get(WMC_Constants.EVENT_WMC).getRecordTypeId();
    private static final Id TASK_RECORD_TYPE = Schema.SObjectType.Task.getRecordTypeInfosByDeveloperName().get(WMC_Constants.TASK_WMC).getRecordTypeId();
    private static final Id DOC_RECORD_TYPE = ConstantsActivityTimeline.DOC_RECORD_TYPE_ID;
    
    /*
     * Sets up test data 
     */  
    @testSetup
    public static void setupTestData() 
    {
        system.debug('*** setupTestData() ***');
        system.debug('000 Limits.getQueries()=' + Limits.getQueries());
        
        // Bypass validation rules
        Bypass_Setting__c byPassSetting = Bypass_Setting__c.getOrgDefaults();
        byPassSetting.Skip_Validation_Rules__c = true;
        upsert byPassSetting;
        
        
        // We will need to create one household with primary members A and B, and C (related, no primary).  
        // Household Member A is related to a Company.  Each has a set of Tasks, Events, Action Plants, and Emails.
        // Some tasks may have SLM and Attachments. 

        // STEP 1: Get Test users to be used in the test
        Id dsProfileId;
        Id adminProfileId; 
        User dsUser, adminUser = null;
        
        adminUser = [SELECT Id FROM User WHERE Profile.Name='System Administrator' AND IsActive=true LIMIT 1];
        dsUser = [SELECT Id FROM User WHERE Profile.Name='DS Associate' AND IsActive=true LIMIT 1];

        system.debug('111 Limits.getQueries()=' + Limits.getQueries());
        System.runAs(adminUser)
        {
            TriggerBase.bypassAll();

            // Create Account Roles (to be used in relationships)
            Id accountRoleRecordTypeId = Schema.SObjectType.FinServ__ReciprocalRole__c.getRecordTypeInfosByDeveloperName().get(WMC_Constants.ACCOUNT_ROLE_RT).getRecordTypeId();
            
            List<Account> newProfiles = new List<Account>();
            
            // Set up a Household Record
            Account mickeyMouseHousehold = createTestHouseholdProfile('Mouse Household');
            newProfiles.add(mickeyMouseHousehold);
            
            // Create 2 Individuals as household members
            Account mickeyMouse = createTestIndividualProfile('Mickey', 'Mouse'); // Primary Contact
            Account minnieMouse = createTestIndividualProfile('Minnie', 'Mouse'); // Spouse
            Account donaldDuck = createTestIndividualProfile('Donald', 'Duck');	// Not primary member in household
            newProfiles.add(mickeyMouse);
            newProfiles.add(minnieMouse);
            newProfiles.add(donaldDuck);
            
            // Create a company that Mickey is linked to
            Account disneyInc = createTestCompanyProfile('Disney Inc.');
            newProfiles.add(disneyInc);
            
            insert newProfiles;
            system.debug('222 Limits.getQueries()=' + Limits.getQueries());
            
            
            // Next, let's add the relationships ACR,AAR, etc.
            
            // First, let's get the corresponding ContactId for the newly added individuals
            List<Contact> newContacts = [SELECT Id, AccountId 
                                         FROM Contact 
                                         WHERE accountId =: mickeyMouse.id OR accountId =: minnieMouse.id OR
                                               accountId =: donaldDuck.id ];
            Contact mickeyMouseContact, minnieMouseContact, donaldDuckContact;
            for (Contact c: newContacts)
            {
                if ( c.AccountId == mickeyMouse.id ){
                    mickeyMouseContact = c;
                }
                else if ( c.AccountId == minnieMouse.id ){
                    minnieMouseContact = c;
                }
                else if ( c.AccountId == donaldDuck.id ){
                    donaldDuckContact = c;
                }
            }
            
            system.debug('333 Limits.getQueries()=' + Limits.getQueries());

            // Let's add ACR's (link Households to household members)
            List <AccountContactRelation> acrList = new List <AccountContactRelation>();
            
            // Create a Role (AAR)
            FinServ__ReciprocalRole__c role = new FinServ__ReciprocalRole__c();
            role.Name = ConstantsActivityTimeline.ROLE_OTHER;
            role.FinServ__InverseRole__c = ConstantsActivityTimeline.ROLE_OTHER;
            role.recordTypeId = AccountRoleRecordTypeId;
            insert role;
            
            // Link Mickey Household to 3 Household members; Only Mickey and Minnie are in the household
            // as a primary group.  Donald Duck is not related directly, so tasks related to Donald
            // should not get returned.
            acrList.add(createTestACR(mickeyMouseHousehold.Id, mickeyMouseContact.Id, true, true, 'P'));
            acrList.add(createTestACR(mickeyMouseHousehold.Id, minnieMouseContact.Id, false, true, 'S'));
            acrList.add(createTestACR(mickeyMouseHousehold.Id, donaldDuckContact.Id, false, false, 'R'));
            insert acrList;
            
            system.debug('444 Limits.getQueries()=' + Limits.getQueries());

			// Create Action Plan Template with 2 Tasks            
            List<ActionPlanTemplate__c> apTemp = WMC_TestFactory.getActionPlanTemplateData(1,'');
            insert apTemp;
            
            system.debug('444 Limits.getQueries()=' + Limits.getQueries());
            
            List<APTemplateTask__c> apTTask = WMC_TestFactory.getActionPlanTemplateTaskData(2,apTemp[0].Id);
            for(Integer i = 0;i < 2; i++){
                apTTask[i].TaskIndex__c = i;
            }
            insert apTTask;
            
            system.debug('555 Limits.getQueries()=' + Limits.getQueries());
            
            // Create 3 Action Plans for Mickey Mouse
            List<ActionPlan__c> actionPlanList = WMC_TestFactory.getActionPlanData(3, mickeyMouse.id, WMC_Constants.TASK_WMC);
            for(integer i = 0; i < 3;i++){
                actionPlanList[i].Is_Pinned__c = true;
                actionPlanList[i].Action_Plan_Template__c = apTemp[0].Id;
                if(i==0){
                    actionPlanList[i].StartDate__c = System.today() + 1; 
                }
                if(i==1){
                    actionPlanList[i].StartDate__c = System.today() - 1;  
                }
                if(i==2){
                    actionPlanList[i].StartDate__c = System.today();  
                }
                actionPlanList[0].Is_Pinned__c = true;
            }
            insert actionPlanList;
            system.debug('666 Limits.getQueries()=' + Limits.getQueries());
            
            List<APTask__c> apTask = WMC_TestFactory.getActionPlanTaskData(2, actionPlanList[0].Id);
            for(Integer i = 0;i < 2; i++){
                apTask[i].TaskIndex__c = i;
                apTask[i].Status__c = 'COMP';
                apTask[i].Priority__c = 'A';
            }
            insert apTask;
            
            List<APEvent__c> apEvent = WMC_TestFactory.getActionPlanScheduleItemRecord(2,actionPlanList[0].Id);
            for(Integer i = 0;i < 2; i++){
                apEvent[i].EventIndex__c = i;
                apEvent[i].Status__c = 'COMP';
            }
            insert apEvent;  
            
            system.debug('777 Limits.getQueries()=' + Limits.getQueries());
            
            List<Task> taskApList = WMC_TestFactory.getTaskData(2,WMC_Constants.TASK_WMC);
            for(Integer i = 0;i < 2;i++){
                taskApList[i].TaskApTask__c = apTask[i].Id;
                taskApList[i].Subject = 'Subject'+i;
                taskApList[i].ActivityDate = date.newInstance(2022, 8, 1);
                taskApList[i].Type = WMC_Constants.PLACECALL;
                taskApList[i].Status = 'COMP';
            }
            insert taskApList;
            
            system.debug('888 Limits.getQueries()=' + Limits.getQueries());
            
            
            //  Create 3 Future Events, and 5 Old Events
            List <Event> eventList = new List<Event>();
            DateTime currentDateTime = DateTime.Now();
            
            // Meetings with Mickey 
            eventList.add(createTestEvent('Future Meeting MM 1', mickeyMouseContact.Id, mickeyMouseHousehold.Id, false, true, currentDateTime.addMonths(1)));
            eventList.add(createTestEvent('Future Meeting MM 2', mickeyMouseContact.Id, mickeyMouse.Id, false, true, currentDateTime.addMonths(2)));
            eventList.add(createTestEvent('Future Meeting MM 3', mickeyMouseContact.Id, mickeyMouse.Id, false, true, currentDateTime.addMonths(3)));
            eventList.add(createTestEvent('Old Meeting MM 1', mickeyMouseContact.Id, mickeyMouseHousehold.Id, false, true, currentDateTime.addMonths(-1)));
            eventList.add(createTestEvent('Old Meeting MM 2', mickeyMouseContact.Id, mickeyMouse.Id, false, true, currentDateTime.addMonths(-2)));
            eventList.add(createTestEvent('Old Meeting MM 3', mickeyMouseContact.Id, mickeyMouse.Id, false, true, currentDateTime.addMonths(-3)));
            eventList.add(createTestEvent('Old Meeting MM 4', mickeyMouseContact.Id, mickeyMouse.Id, false, true, currentDateTime.addMonths(-4)));
            eventList.add(createTestEvent('Old Meeting MM 5', mickeyMouseContact.Id, mickeyMouse.Id, false, true, currentDateTime.addMonths(-5)));
            
            // Meetings with Minnie only (2 old events)
            eventList.add(createTestEvent('Old Meeting with Minnie 1', minnieMouseContact.Id, mickeyMouseHousehold.Id, false, false, currentDateTime.addMonths(-1)));
            eventList.add(createTestEvent('Old Meeting with Minnie 2', minnieMouseContact.Id, mickeyMouseHousehold.Id, false, false, currentDateTime.addMonths(-2)));

            // Meetings with Donald only (1 old events)
            eventList.add(createTestEvent('Old Meeting with Donald 1', donaldDuckContact.Id, mickeyMouseHousehold.Id, false, false, currentDateTime.addMonths(-1)));
            
            insert eventList;
            
            system.debug('999 Limits.getQueries()=' + Limits.getQueries());

            system.debug('currentDateTime.date()=' + currentDateTime.date());

            // Create test tasks
            List<Task> taskList = new List<Task>();
            
            // 3 Future Tasks for Mickey, 2 Completed old tasks
            taskList.add(createTestTask('Future Task Mickey 1', WMC_Constants.TASK_STATUS_NOT_STARTED, mickeyMouse.Id, false, false, currentDateTime.date().addDays(2), 'Document', 'Task', DOC_RECORD_TYPE));
            
            Task mickeyFutureTask2 = createTestTask('Future Task Mickey 2', WMC_Constants.TASK_STATUS_NOT_STARTED, mickeyMouse.Id, false, false, currentDateTime.date().addDays(3), 'Follow up', 'Call', TASK_RECORD_TYPE);
            mickeyFutureTask2.Is_Pinned__c= true;
            taskList.add(mickeyFutureTask2);
            
            taskList.add(createTestTask('Future Task Mickey 3', WMC_Constants.TASK_STATUS_NOT_STARTED, mickeyMouse.Id, false, false, currentDateTime.date().addDays(4), 'Document', 'Task', DOC_RECORD_TYPE));
            taskList.add(createTestTask('Old Task Mickey 1', WMC_Constants.TASK_STATUS_COMPLETE, mickeyMouse.Id, false, false, currentDateTime.date().addDays(-2),'Follow Up', 'Call', TASK_RECORD_TYPE));
            taskList.add(createTestTask('Old Task Mickey 2', WMC_Constants.TASK_STATUS_COMPLETE, mickeyMouse.Id, false, false, currentDateTime.date().addDays(-3), 'Document', 'Task', DOC_RECORD_TYPE));

            // 2 Future Tasks for Minnie, 1 Completed old tasks
            taskList.add(createTestTask('Future Task Minnie 1', WMC_Constants.TASK_STATUS_NOT_STARTED, minnieMouse.Id, false, false, currentDateTime.date().addDays(2), 'Document', 'Task', DOC_RECORD_TYPE));
            taskList.add(createTestTask('Future Task Minnie 2', WMC_Constants.TASK_STATUS_NOT_STARTED, minnieMouse.Id, false, false, currentDateTime.date().addDays(3), 'Follow Up', 'Task', TASK_RECORD_TYPE));
            taskList.add(createTestTask('Old Task Minnie 1', WMC_Constants.TASK_STATUS_COMPLETE, minnieMouse.Id, false, false, currentDateTime.date().addDays(-2), 'Document', 'Task', DOC_RECORD_TYPE));

            // 2 Future Tasks for Donald, 1 Completed old tasks
            taskList.add(createTestTask('Future Task Donald 1', WMC_Constants.TASK_STATUS_NOT_STARTED, donaldDuck.Id, false, false, currentDateTime.date().addDays(2), 'Document', 'Task', DOC_RECORD_TYPE));
            taskList.add(createTestTask('Future Task Donald 2', WMC_Constants.TASK_STATUS_NOT_STARTED, donaldDuck.Id, false, false, currentDateTime.date().addDays(3), 'Document', 'Task', DOC_RECORD_TYPE));
            taskList.add(createTestTask('Old Task Donald 1', WMC_Constants.TASK_STATUS_COMPLETE, donaldDuck.Id, false, false, currentDateTime.date().addDays(-2), 'Document', 'Task', DOC_RECORD_TYPE));
            
            // 2 Future Tasks for Mickey Household directly, 2 Completed old tasks
            taskList.add(createTestTask('Future Task Mickey HH 1', WMC_Constants.TASK_STATUS_NOT_STARTED, mickeyMouseHousehold.Id, false, false, currentDateTime.date().addDays(2), 'Document', 'Task', DOC_RECORD_TYPE));
            taskList.add(createTestTask('Future Task Mickey HH 2', WMC_Constants.TASK_STATUS_NOT_STARTED, mickeyMouseHousehold.Id, false, false, currentDateTime.date().addDays(3), 'Document', 'Task', DOC_RECORD_TYPE));
            taskList.add(createTestTask('Old Task Mickey HH 1', WMC_Constants.TASK_STATUS_COMPLETE, mickeyMouseHousehold.Id, false, false, currentDateTime.date().addDays(-2), 'Document', 'Task', DOC_RECORD_TYPE));
            taskList.add(createTestTask('Old Task Mickey HH 2', WMC_Constants.TASK_STATUS_COMPLETE, mickeyMouseHousehold.Id, false, false, currentDateTime.date().addDays(-3), 'Document', 'Task', DOC_RECORD_TYPE));
            
            // 1 Future Tasks for Disney, 1 Completed old tasks
            taskList.add(createTestTask('Future Task Disney 1', WMC_Constants.TASK_STATUS_NOT_STARTED, disneyInc.Id, false, false, currentDateTime.date().addDays(2), 'Document', 'Task', DOC_RECORD_TYPE));
            taskList.add(createTestTask('Old Task Disney 1', WMC_Constants.TASK_STATUS_COMPLETE, disneyInc.Id, false, false, currentDateTime.date().addDays(-2), 'Document', 'Task', DOC_RECORD_TYPE));
            
            
            insert taskList;
            
            system.debug('10 Limits.getQueries()=' + Limits.getQueries());
            
            // Create 2 Emails for Mickey
            List<EmailMessage> emailList = new List<EmailMessage>();
            
            // Email 1: Sent to 2 Recipients (A, B)
            EmailMessage email1 = createTestEmailMessage( 'testsender@test.ca', 'mickey.aaaaa@test.ca;mickey.bbbbb@test.ca', 
                                                          'Email Subject 1', 'Email Body 11111', mickeyMouse.Id, -1 );
            
            // Email 2: Sent to 1 Recipient (B)
            EmailMessage email2 = createTestEmailMessage( 'testsender@test.ca', 'mickey.bbbbb@test.ca', 
                                                          'Email Subject 2', 'Email Body 22222', mickeyMouse.Id, -1);
            
            emailList.add(email1);
            emailList.add(email2);
            insert emailList;
            
            // Add EmailRelation records for the above emails
            List<EmailMessageRelation> emrList = new List<EmailMessageRelation>();
            
            // Email 1: Sent to 2 Recipients (A, B)
            emrList.add( createTestEmailMessageRelation('testsender@test.ca', null, 'FromAddress', email1.Id) );
            emrList.add( createTestEmailMessageRelation(null, mickeyMouseContact.Id, 'ToAddress', email1.Id) );
            emrList.add( createTestEmailMessageRelation(null, minnieMouseContact.Id, 'ToAddress', email1.Id) );

            // Email 2: Sent to 2 Recipients (A
            emrList.add( createTestEmailMessageRelation('testsender@test.ca', null, 'FromAddress', email2.Id) );
            emrList.add( createTestEmailMessageRelation(null, mickeyMouseContact.Id, 'ToAddress', email2.Id) );
            
            insert emrList;
            
            system.debug('11 Limits.getQueries()=' + Limits.getQueries());
            
            // Add Tags to Tasks for testing
            List<Tag__c> tagList = WMC_TestFactory.getTagData(2, WMC_Constants.WMC_RECORD_TYPE);
            for(integer i = 0; i<2; i++){
                tagList[i].Name = 'tags'+i;
            }
            insert tagList;
            List<Tagged_With__c> taggedWithList = new List<Tagged_With__c>();
            for(Integer i =0 ; i < taskList.size() ; i++) {
                taggedWithList.addAll(WMC_TestFactory.getTaggedData(1, WMC_Constants.WMC_RECORD_TYPE,taskList[i].Id,tagList[0].Id));
            }
            for(Integer i =0 ; i < eventList.size() ; i++) {
                taggedWithList.addAll(WMC_TestFactory.getTaggedData(1, WMC_Constants.WMC_RECORD_TYPE,eventList[i].Id,tagList[0].Id));
            }
            insert taggedWithList;
            
            system.debug('12 Limits.getQueries()=' + Limits.getQueries());
            
            // Add Attachments for Tasks
            List<Document_Management__c> files = new List<Document_Management__c>();
            files.add(createTestAttachment(taskList[0].Id, 'TestFile1.docx', 'docx', 
                                           'https://test.ca/TestFile1.docx', 'F-00001', currentDateTime.addMonths(-5)));
            files.add(createTestAttachment(taskList[0].Id, 'TestFile2.docx', 'docx', 
                                           'https://test.ca/TestFile2.docx', 'F-00002', currentDateTime.addMonths(-5)));
            files.add(createTestAttachment(taskList[0].Id, 'TestFile3.docx', 'docx', 
                                           'https://test.ca/TestFile4.docx', 'F-00003', currentDateTime.addMonths(-5)));
            insert files;
            
            system.debug('13 Limits.getQueries()=' + Limits.getQueries());
            
            
            // Add 2 IER's
            List<et4ae5__IndividualEmailResult__c> ierList = new List<et4ae5__IndividualEmailResult__c>();
            ierList.add(createTestIERs('IER Subject 1 for Mickey', mickeyMouseContact.Id));
            ierList.add(createTestIERs('IER Subject 2 for Mickey', mickeyMouseContact.Id));
            insert ierList;
            
            
            
            
            TriggerBase.clearAllBypasses();
        }
    
    }
    
    
    /*
     *  public static List<sObject> searchWithSOSL(String objectName, String searchKey, String filterCriteria, String additionalFields) 
     *
     * This method tests SOQL; Please note that SOSL in tests always return an empty list.  This method is to help achieve 
     * code coverage only.  Please see reference below for more details:
     * 
     * https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_testing_SOSL.htm
     */  
    @isTest
    private static void searchWithSOSLTest() 
    {
        // Let's create a Profile record (Person Account)
        Test.startTest();
        Account testAcct = createTestIndividualProfile('Johhny', 'Doe');
        insert testAcct;
        system.debug('111 testAcct=' + testAcct);
        
        // Let's create some Tasks with different text
        // There are 3 Tasks ... 
        List<Task> tasks = new List<Task>();
        Task t1 = new Task();
        t1.Subject = 'Apple Oranges Bananas';
        t1.WhatId = testAcct.Id;
        t1.RecordTypeId = ConstantsActivityTimeline.TASK_RECORD_TYPE_ID;
        t1.Description = 'AAAA BBBB CCCC';
        tasks.add(t1);
        
        Task t2 = new Task();
        t2.Subject = 'Test RRRRRRRRRRRR';
        t2.WhatId = testAcct.Id;
        t2.RecordTypeId = ConstantsActivityTimeline.TASK_RECORD_TYPE_ID;
        t2.Description = 'Apple Lions Tigers, and Bears';
        tasks.add(t2);
        
        Task t3 = new Task();
        t3.Subject = 'Mickey Mouse';
        t3.WhatId = testAcct.Id;
        t3.RecordTypeId = ConstantsActivityTimeline.TASK_RECORD_TYPE_ID;
        t3.Description = 'Hello World, Hello World, Hello World, Hello World, Hello World, Hello World - APPLE';
        tasks.add(t3);
        
        insert tasks;
        
        Test.stopTest();
        
        Id [] fixedSearchResults= new Id[3];
        fixedSearchResults[0] = t1.Id;
        fixedSearchResults[1] = t2.Id;
        fixedSearchResults[2] = t3.Id;
        Test.setFixedSearchResults(fixedSearchResults);        
        
        // Test 1: Search for "Apple" - should get 3 results!
        List<Task> taskResults1 = (List<Task>)ActivityTimelineUtility.searchWithSOSL('Task', 'Apple', '', 'Subject');
        system.assertEquals(3, taskResults1.size(), 'Search for Apple should return 3 records');

    }    
    
    
    /*
     * Test 1: Upcoming, Unpinned, No Search Term, No Date entered.  Test for Household
     * 
     * public static List <ActivityDataWrapper> getRelatedActivities(Id profileId, List <String> lstType, boolean showOnlyPinned, 
     *                                                            String dateEntered, String dateToFilter, String searchText, 
     *                                                             String range, boolean refreshData) 
     */  
    @isTest
    private static void getRelatedActivitiesTest_MouseHousehold()
    {
        system.debug('*** getRelatedActivitiesTest_MouseHousehold() - START ***');
        system.debug('getRelatedActivitiesTest_MouseHousehold()--> 1 Limits.getQueries()=' + Limits.getQueries());

		// Retrieve the test Profiles that were created
        Account mickeyMouseHousehold = [SELECT Id, Name, isPersonAccount FROM Account WHERE Name= 'Mouse Household' LIMIT 1];
        system.debug('mickeyMouseHousehold=' + mickeyMouseHousehold);
        
        // For Mouse Household, there should be 2 Action Plans (Mickey), 3 Future Events (3 with Mickey), 
        // 7 Future Tasks (3 with Mickey, 2 for Minnie, 2 for household directly), 2 Emails (Mickey), 
        // and 2 IER's (Mickey) so 16 in total
        List <ActivityDataWrapper> results_MouseHouseholdUpcoming = 
                    ActivityTimelineUtility.getRelatedActivities(mickeyMouseHousehold.Id, null, false, null, null, null, 
                                                                 ConstantsActivityTimeline.DATE_RANGE_UPCOMING, true);
        
        system.debug('getRelatedActivitiesTest()--> 3 Limits.getQueries()=' + Limits.getQueries());
        
        Integer i=0;
        for ( ActivityDataWrapper wrapper: results_MouseHouseholdUpcoming )
        {
            system.debug(i + ' - Mouse Household wrapper =' + wrapper);
            system.debug(i + ' - Mouse Household wrapper.actvityCategory=' + wrapper.actvityCategory);
            system.debug(i + ' - Mouse Household wrapper.subject=' + wrapper.subject);
            system.debug(i + ' - Mouse Household wrapper.activityDate=' + wrapper.activityDate);
            i++;
        }        

        system.assert( results_MouseHouseholdUpcoming != null && results_MouseHouseholdUpcoming.size() > 0 );
        system.debug('results_MouseHouseholdUpcoming.size()=' + results_MouseHouseholdUpcoming.size());
        system.assertEquals( 16, results_MouseHouseholdUpcoming.size(), 
                            'Mickey Mouse Household should be 16 activities returned');

        system.debug('getRelatedActivitiesTest()--> 4 Limits.getQueries()=' + Limits.getQueries());
        
    }
    
    
    /*
     * Test 1: Upcoming, Pinned, No Search Term, No Date entered.  Test for Household
     * 
     * public static List <ActivityDataWrapper> getRelatedActivities(Id profileId, List <String> lstType, boolean showOnlyPinned, 
     *                                                            String dateEntered, String dateToFilter, String searchText, 
     *                                                             String range, boolean refreshData) 
     */  
    @isTest
    private static void getRelatedActivitiesTest_MouseHousehold_Pinned()
    {
        system.debug('*** getRelatedActivitiesTest_MouseHousehold_Pinned() - START ***');

		// Retrieve the test Profiles that were created
        Account mickeyMouseHousehold = [SELECT Id, Name, isPersonAccount FROM Account WHERE Name= 'Mouse Household' LIMIT 1];
        system.debug('mickeyMouseHousehold=' + mickeyMouseHousehold);
        
        // For Mouse Household, there should be 2 Action Plans pinned (Mickey), and 1 Task pinned (Mickey)
        List <ActivityDataWrapper> results_MouseHouseholdUpcoming = 
                    ActivityTimelineUtility.getRelatedActivities(mickeyMouseHousehold.Id, null, true, null, null, null, 
                                                                 ConstantsActivityTimeline.DATE_RANGE_UPCOMING, true);
        
        system.assert( results_MouseHouseholdUpcoming != null && results_MouseHouseholdUpcoming.size() > 0 );
        system.debug('results_MouseHouseholdUpcoming.size()=' + results_MouseHouseholdUpcoming.size());
        system.assertEquals( 3, results_MouseHouseholdUpcoming.size(), 
                            'Mickey Mouse Household should be 3 pinned activities returned');

    }
    
    
    
    /*
     * Test 1: Upcoming, Unpinned, No Seach Tem, No Date entered.  Only for Mickey Mouse directly
     * 
     * public static List <ActivityDataWrapper> getRelatedActivities(Id profileId, List <String> lstType, boolean showOnlyPinned, 
     *                                                            String dateEntered, String dateToFilter, String searchText, 
     *                                                             String range, boolean refreshData) 
     */  
    @isTest
    private static void getRelatedActivitiesTest_MickeyOnly()
    {
        system.debug('*** getRelatedActivitiesTest_MickeyOnly() - START ***');
        system.debug('getRelatedActivitigetRelatedActivitiesTest_MickeyOnlyesTest()--> 1 Limits.getQueries()=' + Limits.getQueries());

		// Retrieve the test Profiles that were created
        Account mickeyMouse = [SELECT Id, Name, isPersonAccount FROM Account WHERE Name='Mickey Mouse' LIMIT 1];
        system.debug('mickeyMouse=' + mickeyMouse);
        
        // For Mickey, there should be 2 Action Plans, 3 Future Events, 3 Future Tasks, 2 Emails, 
        // and 2 IER's, so 12 in total
        List <ActivityDataWrapper> results_MickeyUpcoming = 
                    ActivityTimelineUtility.getRelatedActivities(mickeyMouse.Id, null, false, null, null, null, 
                                                                 ConstantsActivityTimeline.DATE_RANGE_UPCOMING, true);
        
        system.assert( results_MickeyUpcoming != null && results_MickeyUpcoming.size() > 0 );
        system.debug('results_MickeyUpcoming.size()=' + results_MickeyUpcoming.size());

        Integer i=0;
        Integer numTasks = 0;
        Integer numEvents = 0;
        Integer numActionPlans = 0;
        Integer numEmails = 0;
        Integer numIERs = 0;
        for ( ActivityDataWrapper wrapper: results_MickeyUpcoming )
        {
            system.debug(i + ' - Mickey wrapper =' + wrapper);
            system.debug(i + ' - Mickey wrapper.actvityCategory=' + wrapper.actvityCategory);
            system.debug(i + ' - Mickey wrapper.subject=' + wrapper.subject);
            system.debug(i + ' - Mickey wrapper.activityDate=' + wrapper.activityDate);
            
            if ( wrapper.actvityCategory == 'email'){
                numEmails++;
            }
            if ( wrapper.actvityCategory == 'task'){
                numTasks++;
            }
            if ( wrapper.actvityCategory == 'event'){
                numEvents++;
            }
            
            i++;
        }
        
        system.assertEquals( 12, results_MickeyUpcoming.size(), 'Mickey Mouse should be 12 activities returned');
        system.assertEquals( 3, numEvents, 'Mickey Mouse should be 3 future events');
        system.assertEquals( 4, numEmails, 'Mickey Mouse should be 4 future emails: 2 sfdc, 2 ier');
    }
    

    /*
     * Test 1: Upcoming, Unpinned, With Date Entered and Date Filters.  Only for Mickey Mouse directly
     * 
     * public static List <ActivityDataWrapper> getRelatedActivities(Id profileId, List <String> lstType, boolean showOnlyPinned, 
     *                                                            String dateEntered, String dateToFilter, String searchText, 
     *                                                             String range, boolean refreshData) 
     */  
    @isTest
    private static void getRelatedActivitiesTest_MickeyOnlyWithDateFilters()
    {
        system.debug('*** getRelatedActivitiesTest_MickeyOnlyWithDateFilters() - START ***');
        system.debug('getRelatedActivitiesTest_MickeyOnlyWithDateFilters()--> 1 Limits.getQueries()=' + Limits.getQueries());

		// Retrieve the test Profiles that were created
        Account mickeyMouse = [SELECT Id, Name, isPersonAccount FROM Account WHERE Name='Mickey Mouse' LIMIT 1];
        system.debug('mickeyMouse=' + mickeyMouse);
        
        // For Mickey, there should be 2 Action Plans, 3 Future Events, 3 Future Tasks, 2 Emails, 
        // and 2 IER's, so 12 in total
        // 
        DateTime dateOfFirstTask = DateTime.Now().addDays(3); 
        system.debug('dateOfFirstTask=' + dateOfFirstTask);
        
        String dateEntered = dateOfFirstTask.formatGMT('yyyy-MM-dd');
        Date dateEntered2 = Date.valueOf(dateEntered);
        
        system.debug('dateEntered=' + dateEntered);
        system.debug('dateEntered2=' + dateEntered2);
        system.debug('WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW');
        
        //------------------------
        integer taskIndex=0;
        for ( Task t: [SELECT Id, Subject, ActivityDate, Status FROM Task ORDER BY ActivityDate]){
            system.debug(taskIndex + ' - t=' + t);
            taskIndex++;
        }

        taskIndex=0;
		String taskQuery = 'SELECT Id, Subject, ActivityDate, Status FROM Task WHERE ActivityDate =: dateEntered2  AND IsClosed=false AND ( ActivityDate > TODAY OR status != \'COMP\')  AND ( IsArchived=TRUE OR IsDeleted=FALSE ) ORDER BY ActivityDate';
        List<Task> tList2 = Database.Query(taskQuery);
        for ( Task t: tList2){
            system.debug(taskIndex + ' - t2=' + t);
            taskIndex++;
        }

        
        List <ActivityDataWrapper> results_MickeyUpcoming = 
                    ActivityTimelineUtility.getRelatedActivities(mickeyMouse.Id, null, false, dateEntered, null, null, 
                                                                 ConstantsActivityTimeline.DATE_RANGE_UPCOMING, true);
        
        system.assert( results_MickeyUpcoming != null && results_MickeyUpcoming.size() > 0 );
        system.debug('results_MickeyUpcoming.size()=' + results_MickeyUpcoming.size());

        
        system.assertEquals( 1, results_MickeyUpcoming.size(), 'Mickey Mouse should be 1 activities returned for the date entered');
    }

    
    /*
     * Test 1: Upcoming, Unpinned, With set type for Tasks only.  Only for Mickey Mouse directly
     * 
     * public static List <ActivityDataWrapper> getRelatedActivities(Id profileId, List <String> lstType, boolean showOnlyPinned, 
     *                                                            String dateEntered, String dateToFilter, String searchText, 
     *                                                             String range, boolean refreshData) 
     */  
    @isTest
    private static void getRelatedActivitiesTest_MickeyOnlyWithTaskOnlySetType()
    {
        system.debug('*** getRelatedActivitiesTest_MickeyOnlyWithTaskOnlySetType() - START ***');

        List <String> lstType = new List <String>();
        lstType.add(ConstantsActivityTimeline.SET_TYPE_DOCUMENT);
        
		// Retrieve the test Profiles that were created
        Account mickeyMouse = [SELECT Id, Name, isPersonAccount FROM Account WHERE Name='Mickey Mouse' LIMIT 1];
        system.debug('mickeyMouse=' + mickeyMouse);
        
        // For Mickey, there should be 3 Future Tasks only (everything else should get filtered out)
        List <ActivityDataWrapper> results_MickeyUpcoming = 
                    ActivityTimelineUtility.getRelatedActivities(mickeyMouse.Id, lstType, false, null, null, null, 
                                                                 ConstantsActivityTimeline.DATE_RANGE_UPCOMING, true);
        
        system.assert( results_MickeyUpcoming != null && results_MickeyUpcoming.size() > 0, 'Some results should get returned' );
        system.debug('results_MickeyUpcoming.size()=' + results_MickeyUpcoming.size());

        system.assertEquals( 2, results_MickeyUpcoming.size(), 'Mickey Mouse should be 2 Documents returned');
        
    }
    
    
    /*
     * Test 1: Upcoming, Pinned, No Search Term, No Date entered.  Only for Mickey Mouse directly
     * 
     * public static List <ActivityDataWrapper> getRelatedActivities(Id profileId, List <String> lstType, boolean showOnlyPinned, 
     *                                                            String dateEntered, String dateToFilter, String searchText, 
     *                                                             String range, boolean refreshData) 
     */  
    @isTest
    private static void getRelatedActivitiesTest_MickeyOnlyPinned()
    {
        system.debug('*** getRelatedActivitiesTest_MickeyOnlyPinned() - START ***');
        system.debug('getRelatedActivitiesTest_MickeyOnlyPinned()--> 1 Limits.getQueries()=' + Limits.getQueries());

		// Retrieve the test Profiles that were created
        Account mickeyMouse = [SELECT Id, Name, isPersonAccount FROM Account WHERE Name='Mickey Mouse' LIMIT 1];
        system.debug('mickeyMouse=' + mickeyMouse);
        
        // For Mickey, there should be 2 Action Plans that are pinned, and 1 task that is pinned
        List <ActivityDataWrapper> results_MickeyUpcoming = 
                    ActivityTimelineUtility.getRelatedActivities(mickeyMouse.Id, null, true, null, null, null, 
                                                                 ConstantsActivityTimeline.DATE_RANGE_UPCOMING, true);
        
        system.assert( results_MickeyUpcoming != null && results_MickeyUpcoming.size() > 0 );
        system.debug('results_MickeyUpcoming.size()=' + results_MickeyUpcoming.size());

        system.assertEquals(3, results_MickeyUpcoming.size(), 'Mickey Mouse should have 3 pinned activities returned');
    }
    
    
    
    
    /*
     * Test 1: Upcoming, Unpinned, No Seach Tem, No Date entered.  For Minnie Mouse only
     * 
     * public static List <ActivityDataWrapper> getRelatedActivities(Id profileId, List <String> lstType, boolean showOnlyPinned, 
     *                                                            String dateEntered, String dateToFilter, String searchText, 
     *                                                             String range, boolean refreshData) 
     */  
    @isTest
    private static void getRelatedActivitiesTest_MinnieOnly()
    {
        system.debug('*** getRelatedActivitiesTest_MinnieOnly() - START ***');
        system.debug('getRelatedActivitiesTest_MinnieOnly()--> 1 Limits.getQueries()=' + Limits.getQueries());

		// Retrieve the test Profiles that were created
        Account minnieMouse = [SELECT Id, Name, isPersonAccount FROM Account WHERE Name = 'Minnie Mouse' LIMIT 1];
        system.debug('minnieMouse=' + minnieMouse);

        // For Minnie, there should be 0 Action Plans, 0 Future Events, 2 Future Tasks, 
        // 1 Email (where Minnie is one of the recipients), so 3 in total
        List <ActivityDataWrapper> results_MinnieUpcoming = 
                    ActivityTimelineUtility.getRelatedActivities(minnieMouse.Id, null, false, null, null, null, 
                                                                 ConstantsActivityTimeline.DATE_RANGE_UPCOMING, true);
        
        system.assert( results_MinnieUpcoming != null && results_MinnieUpcoming.size() > 0 );
        system.debug('results_MinnieUpcoming.size()=' + results_MinnieUpcoming.size());
        system.assertEquals( 3, results_MinnieUpcoming.size(), 'There should be 3 activities returned');

        Integer i=0;
        for ( ActivityDataWrapper wrapper: results_MinnieUpcoming )
        {
            system.debug(i + ' - Minnie wrapper =' + wrapper);
            system.debug(i + ' - Minnie wrapper.actvityCategory=' + wrapper.actvityCategory);
            system.debug(i + ' - Minnie wrapper.subject=' + wrapper.subject);
            system.debug(i + ' - Minnie wrapper.activityDate=' + wrapper.activityDate);
            i++;
        }        

    }
    
    
    
    /*
     * Test 1: Past, Unpinned, No Search Term, No Date entered.  Test for Household
     * 
     * public static List <ActivityDataWrapper> getRelatedActivities(Id profileId, List <String> lstType, boolean showOnlyPinned, 
     *                                                            String dateEntered, String dateToFilter, String searchText, 
     *                                                             String range, boolean refreshData) 
     */  
    @isTest
    private static void getRelatedActivitiesTest_MouseHousehold_Past()
    {
        system.debug('*** getRelatedActivitiesTest_MouseHousehold_Past() - START ***');

		// Retrieve the test Profiles that were created
        Account mickeyMouseHousehold = [SELECT Id, Name, isPersonAccount FROM Account WHERE Name= 'Mouse Household' LIMIT 1];
        system.debug('mickeyMouseHousehold=' + mickeyMouseHousehold);
        
        // For Mouse Household, 1 Action Plans, 5 Old Meetings (Mickey + Household), 2 Old Meetings (Minnie), 
        // 1 Old Meeting (with Donald and related to Mouse Household),
        // 2 Old Tasks (Mickey), 1 Old Task (Minnie), 2 Old tasks (Mouse Household-Direct), 1 Old Task (Disney),
        // 2 Emails, 2 IERs
        // Total: 18
        List <ActivityDataWrapper> results_MouseHouseholdPast = 
                    ActivityTimelineUtility.getRelatedActivities(mickeyMouseHousehold.Id, null, false, null, null, null, 
                                                                 ConstantsActivityTimeline.DATE_RANGE_PAST, true);
        
        system.debug('getRelatedActivitiesTest()--> 3 Limits.getQueries()=' + Limits.getQueries());
        
        Integer i=0;
        for ( ActivityDataWrapper wrapper: results_MouseHouseholdPast )
        {
            system.debug(i + ' - Mouse Household wrapper =' + wrapper);
            system.debug(i + ' - Mouse Household wrapper.actvityCategory=' + wrapper.actvityCategory);
            system.debug(i + ' - Mouse Household wrapper.subject=' + wrapper.subject);
            system.debug(i + ' - Mouse Household wrapper.activityDate=' + wrapper.activityDate);
            i++;
        }        

        system.assert( results_MouseHouseholdPast != null && results_MouseHouseholdPast.size() > 0 );
        system.debug('results_MouseHouseholdPast.size()=' + results_MouseHouseholdPast.size());
        system.assertEquals( 18, results_MouseHouseholdPast.size(), 
                            'Mickey Mouse Household should be 18 activities returned');

        system.debug('getRelatedActivitiesTest()--> 4 Limits.getQueries()=' + Limits.getQueries());
        
    }
    
    
    
    /*
     * Test 1: Upcoming, Unpinned, No Search Tem, No Date entered.  Only for Mickey Mouse directly
     * 
     * public static List <ActivityDataWrapper> getRelatedActivities(Id profileId, List <String> lstType, boolean showOnlyPinned, 
     *                                                            String dateEntered, String dateToFilter, String searchText, 
     *                                                             String range, boolean refreshData) 
     */  
    @isTest
    private static void getRelatedActivitiesTest_MickeyOnly_Past()
    {
        system.debug('*** getRelatedActivitiesTest_MickeyOnly() - START ***');
        system.debug('getRelatedActivitigetRelatedActivitiesTest_MickeyOnlyesTest()--> 1 Limits.getQueries()=' + Limits.getQueries());

		// Retrieve the test Profiles that were created
        Account mickeyMouse = [SELECT Id, Name, isPersonAccount FROM Account WHERE Name='Mickey Mouse' LIMIT 1];
        system.debug('mickeyMouse=' + mickeyMouse);
        
        // For Mickey Mouse, there are:
        // 1 Action Plans, 4 Old Meetings (Mickey), 2 Old Tasks (Mickey), 1 Old Task (Disney),
        // 2 Emails, 2 IERs
        // Total: 12
        List <ActivityDataWrapper> results_MickeyPast = 
                    ActivityTimelineUtility.getRelatedActivities(mickeyMouse.Id, null, false, null, null, null, 
                                                                 ConstantsActivityTimeline.DATE_RANGE_PAST, true);
        
        system.assert( results_MickeyPast != null && results_MickeyPast.size() > 0 );
        system.debug('results_MickeyPast.size()=' + results_MickeyPast.size());

        system.assertEquals( 12, results_MickeyPast.size(), 'Mickey Mouse should be 12 activities returned');
    }


    /*
     * Test 1: Past, Unpinned, No Search Tem, No Date entered, with Date Filter (Past 1 Week).  Only for Mickey Mouse directly
     * 
     * public static List <ActivityDataWrapper> getRelatedActivities(Id profileId, List <String> lstType, boolean showOnlyPinned, 
     *                                                            String dateEntered, String dateToFilter, String searchText, 
     *                                                             String range, boolean refreshData) 
     */  
    @isTest
    private static void getRelatedActivitiesTest_MickeyOnly_Past_DateToFilter()
    {
        system.debug('*** getRelatedActivitiesTest_MickeyOnly_Past_DateToFilter() - START ***');
        system.debug('getRelatedActivitigetRelatedActivitiesTest_MickeyOnlyesTest()--> 1 Limits.getQueries()=' + Limits.getQueries());

		// Retrieve the test Profiles that were created
        Account mickeyMouse = [SELECT Id, Name, isPersonAccount FROM Account WHERE Name='Mickey Mouse' LIMIT 1];
        system.debug('mickeyMouse=' + mickeyMouse);
        
        // For Mickey Mouse, there are:
        // 1 Action Plans, 4 Old Meetings (Mickey), 2 Old Tasks (Mickey), 1 Old Task (Disney),
        // 2 Emails, 2 IERs
        // Total: 12
        List <ActivityDataWrapper> results_MickeyPast = 
                    ActivityTimelineUtility.getRelatedActivities(mickeyMouse.Id, null, false, null, 'LAST_N_DAYS:3', null, 
                                                                 ConstantsActivityTimeline.DATE_RANGE_PAST, true);
        
        system.assert( results_MickeyPast != null && results_MickeyPast.size() > 0 );
        system.debug('results_MickeyPast.size()=' + results_MickeyPast.size());

        system.assertEquals( 4, results_MickeyPast.size(), 'Mickey Mouse should be 4 activities returned');
        
        List <ActivityDataWrapper> results_MickeyPast2 = 
                    ActivityTimelineUtility.getRelatedActivities(mickeyMouse.Id, null, false, null, 'LAST_N_YEARS:3', null, 
                                                                 ConstantsActivityTimeline.DATE_RANGE_PAST, true);
        
        system.assert( results_MickeyPast2 != null && results_MickeyPast2.size() > 0 );
        system.debug('results_MickeyPast2.size()=' + results_MickeyPast2.size());

        system.assertEquals( 12	, results_MickeyPast2.size(), 'Mickey Mouse should be 12 activities returned');
            
    }

    

    /*
     * Test 1: Past, Unpinned, with a Search Tem, No Date entered.  Only for Mickey Mouse directly
     * 
     * public static List <ActivityDataWrapper> getRelatedActivities(Id profileId, List <String> lstType, boolean showOnlyPinned, 
     *                                                            String dateEntered, String dateToFilter, String searchText, 
     *                                                             String range, boolean refreshData) 
     */  
    @isTest
    private static void getRelatedActivitiesTest_MickeyOnly_Past_Search()
    {
        system.debug('*** getRelatedActivitiesTest_MickeyOnly() - START ***');
        system.debug('getRelatedActivitigetRelatedActivitiesTest_MickeyOnlyesTest()--> 1 Limits.getQueries()=' + Limits.getQueries());

		// Retrieve the test Profiles that were created
        Account mickeyMouse = [SELECT Id, Name, isPersonAccount FROM Account WHERE Name='Mickey Mouse' LIMIT 1];
        system.debug('mickeyMouse=' + mickeyMouse);
        
        // For Mickey Mouse, there are:
        // 1 Action Plans, 1 Old Meetings (Mickey), 1 Old Tasks (Mickey), 1 Old Task (Disney),
        // 2 Emails, 0 IERs (IER's default to 10 days old)
        // Total: 12

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId=:mickeyMouse.Id AND isClosed=true];
        Id [] fixedSearchResults= new Id[2];
        fixedSearchResults[0] = tasks[0].Id;
        fixedSearchResults[1] = tasks[1].Id;
        Test.setFixedSearchResults(fixedSearchResults);        

        List <ActivityDataWrapper> results_MickeyPast = 
                    ActivityTimelineUtility.getRelatedActivities(mickeyMouse.Id, null, false, null, null, 'Old Task Mickey', 
                                                                 ConstantsActivityTimeline.DATE_RANGE_PAST, true);
        
        system.assertEquals( 2, results_MickeyPast.size());
    }
    

    /*
     *  public static ActivityIdSetObj getActivityRelationships(Id recordId, Boolean refreshData)
     */ 
    @isTest
    private static void getActivityRelationshipsTest() 
    {
		// Retrieve the test Profiles that were created
        Account mickeyMouse = [SELECT Id, Name, isPersonAccount FROM Account WHERE Name='Mickey Mouse' LIMIT 1];
        system.debug('mickeyMouse=' + mickeyMouse);
        
        ActivityTimelineUtility.ActivityIdSetObj idSetObj = ActivityTimelineUtility.getActivityRelationships(mickeyMouse.Id, true);
        
        system.assert( idSetObj != null && idSetObj.contactIdSet.size() > 0 );
    }
    

    /*
     * private static EmailIdSetObj getEmailIdSetInfo(String profileId, ActivityIdSetObj idSets)
     */
    @isTest
    private static void getEmailIdSetInfoTest() 
    {
		// Retrieve the test Profiles that were created
        Account mickeyMouse = [SELECT Id, Name, isPersonAccount FROM Account WHERE Name='Mickey Mouse' LIMIT 1];
        system.debug('mickeyMouse=' + mickeyMouse);
        
        ActivityTimelineUtility.ActivityIdSetObj idSetObj = ActivityTimelineUtility.getActivityRelationships(mickeyMouse.Id, true);
        
        system.assert( idSetObj != null && idSetObj.contactIdSet.size() > 0 );
        
        ActivityTimelineUtility.EmailIdSetObj emailIdSetObjTest 
            				= ActivityTimelineUtility.getEmailIdSetInfo(mickeyMouse.Id, idSetObj);
        system.assert(emailIdSetObjTest != null && emailIdSetObjTest.emailMessageIdSet.size() > 0 );
    }    


    /*
     * private static EmailIdSetObj getEmailIdSetInfo(String profileId, ActivityIdSetObj idSets)
     * 
     * Test logic for additional relationships
     */
    @isTest
    private static void getEmailIdSetInfoTest_AdditionalRelationships() 
    {
		// Retrieve the test Profiles that were created
        Account tonyStark = createTestIndividualProfile('Tony', 'Stark');
        tonyStark.Crm_Oid__c = 'tonyStark-' + Integer.valueof((Math.random() * 10));
        system.debug('tonyStark=' + tonyStark);
        insert tonyStark;
        
        // Create an email with Additional Relationships
        EmailMessage email1 = createTestEmailMessage( 'testsender@test.ca', 'mickey.aaaaa@test.ca', 
                                                      'Email Subject 1', 'Email Body 11111', tonyStark.Id, -1 );
		email1.Additional_Relationships__c = tonyStark.Crm_Oid__c;
        insert email1;
        
        Id [] fixedSearchResults= new Id[1];
        fixedSearchResults[0] = email1.Id;
        Test.setFixedSearchResults(fixedSearchResults);        
        
        
        ActivityTimelineUtility.ActivityIdSetObj idSetObj = ActivityTimelineUtility.getActivityRelationships(tonyStark.Id, true);
        
        system.assert( idSetObj != null && idSetObj.contactIdSet.size() > 0 );
        
        ActivityTimelineUtility.EmailIdSetObj emailIdSetObjTest 
            				= ActivityTimelineUtility.getEmailIdSetInfo(tonyStark.Id, idSetObj);
        system.assert(emailIdSetObjTest != null && emailIdSetObjTest.emailMessageIdSet.size() != null );
    }    


    /*
     * private static EmailIdSetObj getEmailIdSetInfo(String profileId, ActivityIdSetObj idSets)
     * 
     * Test logic for additional relationships, for Exception Case to ensure there is no error
     * if profile id is found in the email body
     */
    @isTest
    private static void getEmailIdSetInfoTest_AdditionalRelationships_Exception() 
    {
		// Retrieve the test Profiles that were created
        Account tonyStark = createTestIndividualProfile('Tony', 'Stark');
        tonyStark.Crm_Oid__c = 'tonyStark-' + Integer.valueof((Math.random() * 10));
        system.debug('tonyStark=' + tonyStark);
        insert tonyStark;

        Account bruceBanner = createTestIndividualProfile('Bruce', 'Banner');
        bruceBanner.Crm_Oid__c = 'bruceBanner-' + Integer.valueof((Math.random() * 10));
        system.debug('bruceBanner=' + bruceBanner);
        insert bruceBanner;

        
        // Create an email with Additional Relationships
        String emailTextBody = 'Hello ' + bruceBanner.Crm_Oid__c + ' and Id is ' + bruceBanner.Id;
        EmailMessage email1 = createTestEmailMessage( 'testsender@test.ca', 'mickey.aaaaa@test.ca', 
                                                      'Email Subject 222', emailTextBody, tonyStark.Id, -1 );
		email1.Additional_Relationships__c = null;
        insert email1;
        
        Id [] fixedSearchResults= new Id[1];
        fixedSearchResults[0] = email1.Id;
        Test.setFixedSearchResults(fixedSearchResults);        
        
        
        ActivityTimelineUtility.ActivityIdSetObj idSetObj = ActivityTimelineUtility.getActivityRelationships(tonyStark.Id, true);
        
        system.assert( idSetObj != null && idSetObj.contactIdSet.size() > 0 );
        
        ActivityTimelineUtility.EmailIdSetObj emailIdSetObjTest 
            				= ActivityTimelineUtility.getEmailIdSetInfo(tonyStark.Id, idSetObj);
        system.assert(emailIdSetObjTest != null && emailIdSetObjTest.emailMessageIdSet.size() != null );
    }    

    
    
    /*
     * private static EmailIdSetObj getEmailIdSetInfo(String profileId, ActivityIdSetObj idSets)
     * 
     * Test logic for converted lead
     */
    @isTest
    private static void getEmailIdSetInfoTest_ConvertedLead() 
    {
		// Retrieve the test Profiles that were created
        Account tonyStark = createTestIndividualProfile('Tony', 'Stark');
        tonyStark.Crm_Oid__c = 'tonyStark-' + Integer.valueof((Math.random() * 10));
        system.debug('tonyStark=' + tonyStark);
        insert tonyStark;
        
        // Create a Converted Lead
        Lead convertedLead = new Lead();
        convertedLead.IsConverted = true;
        convertedLead.ConvertedAccountId = tonyStark.Id;
        convertedLead.FirstName = 'Tony2';
        convertedLead.LastName = 'Stark2';
        insert convertedLead;
        
        // Create an email with Additional Relationships
        EmailMessage email1 = createTestEmailMessage( 'testsender@test.ca', 'mickey.aaaaa@test.ca', 
                                                      'EmailMessage', 'EmailMessage', tonyStark.Id, -1 );
		email1.Additional_Relationships__c = 'Individual: ' + tonyStark.Crm_Oid__c + ', Household: xxxxxxxxxx';
        insert email1;
        
        Id [] fixedSearchResults= new Id[1];
        fixedSearchResults[0] = email1.Id;
        Test.setFixedSearchResults(fixedSearchResults);        
        
        ActivityTimelineUtility.ActivityIdSetObj idSetObj = ActivityTimelineUtility.getActivityRelationships(tonyStark.Id, true);
        
        system.assert( idSetObj != null && idSetObj.contactIdSet.size() > 0 );
        
        ActivityTimelineUtility.EmailIdSetObj emailIdSetObjTest 
            				= ActivityTimelineUtility.getEmailIdSetInfo(tonyStark.Id, idSetObj);
        system.assert(emailIdSetObjTest != null && emailIdSetObjTest.emailMessageIdSet.size() != null );
    }    
    
    
    
    /*
     *  public static Map <String, String> getTaskStatusPicklist() 
     */ 
    @isTest
    private static void getTaskStatusPicklistTest() 
    {
        Map<String, String> taskStatusOptionMap = ActivityTimelineUtility.getTaskStatusPicklist();
        system.assert( taskStatusOptionMap != null && taskStatusOptionMap.size() > 0 );
    }
    
    
    /*
     *  public static Id getPersonContactId(Id profileId)
     */  
    @isTest
    private static void getPersonContactIdTest() 
    {
        system.debug('*** getPersonContactIdTest() - START ***');
        system.debug('Limits.getQueries()=' + Limits.getQueries());
        
        // Let's create a Profile record (Person Account)
        Test.startTest();
        Account testAcct = [SELECT Id, Name, isPersonAccount FROM Account WHERE Name='Mickey Mouse' LIMIT 1];
        system.debug('111 testAcct=' + testAcct);
        Test.stopTest();
        
        id contactId = ActivityTimelineUtility.getPersonContactId(testAcct.Id);
            
        // Query the data
        Account newProfile = [SELECT Id, PersonContactId 
                              FROM Account WHERE ID =: testAcct.Id];
        
        system.assertEquals(newProfile.PersonContactId, contactId);
        
        // Call one more time to test getting data from cache
        id contactId2 = ActivityTimelineUtility.getPersonContactId(testAcct.Id);
        system.assertEquals(contactId2, contactId);
    }


    /*
     * public static String getFilterCriteria(String initialFilters, getFilterCriteria, Date startDate, Date endDate, Boolean isDueDate,
     *                                        String dateFieldName, String assignedTo, String createdBy)
     */  
    @isTest
    private static void getFilterCriteriaTest() 
    {
        system.debug('*** getFilterCriteriaTest() - START ***');
        
        Date startDate = Date.Today();
        Date endDate = startDate.addDays(4);
        String filterCriteria = ActivityTimelineUtility.getFilterCriteria(ConstantsActivityTimeline.TASK_INITIAL_FILTERS, null, 
                                                                          startDate, endDate, true, 'ActivityDate',
                                                                          UserInfo.getUserId(), UserInfo.getUserId() );
            
        system.debug( filterCriteria != null && !String.isBlank(filterCriteria));

        String filterCriteria2 = ActivityTimelineUtility.getFilterCriteria(ConstantsActivityTimeline.TASK_INITIAL_FILTERS, null,
                                                                          startDate, null, true, 'ActivityDate',
                                                                          UserInfo.getUserId(), UserInfo.getUserId() );
            
        system.debug( filterCriteria2 != null && !String.isBlank(filterCriteria2));

        String filterCriteria3 = ActivityTimelineUtility.getFilterCriteria(ConstantsActivityTimeline.TASK_INITIAL_FILTERS, null,
                                                                          startDate, null, false, 'ActivityDate',
                                                                          UserInfo.getUserId(), UserInfo.getUserId() );
            
        system.debug( filterCriteria3 != null && !String.isBlank(filterCriteria3));

        String filterCriteria4 = ActivityTimelineUtility.getFilterCriteria(ConstantsActivityTimeline.EVENT_INITIAL_FILTERS, startDate,
                                                                          null, null, false, 'ActivityDate',
                                                                          UserInfo.getUserId(), UserInfo.getUserId() );
            
        system.debug( filterCriteria4 != null && !String.isBlank(filterCriteria4));

    }

    
    /*
     * Test to verify variuos SetType Method 
     */  
    @isTest
    private static void verifySetTypeMethodsTest() 
    {
        system.debug('*** verifySetTypeMethodsTest() - START ***');
        
        Set<String> setType1 = new Set<String>();
        setType1.add(ConstantsActivityTimeline.SET_TYPE_TASK);
        setType1.add(ConstantsActivityTimeline.SET_TYPE_CALL);
        setType1.add(ConstantsActivityTimeline.SET_TYPE_SSC_EMAIL);
        
        Boolean isTaskSetType = ActivityTimelineUtility.isTaskSetType(setType1);
        system.assertEquals(true, isTaskSetType);
        
        Boolean isEventSetType = ActivityTimelineUtility.isEventSetType(setType1);
        system.assertEquals(false, isEventSetType);
        
        Boolean isActionPlanSetType = ActivityTimelineUtility.isActionPlanSetType(setType1);
        system.assertEquals(false, isActionPlanSetType);
        
        Boolean isSlmSetType = ActivityTimelineUtility.isSlmSetType(setType1);
        system.assertEquals(false, isSlmSetType);

        Boolean isEmailSSCSetType = ActivityTimelineUtility.isSSCEmailSetType(setType1);
        system.assertEquals(true, isEmailSSCSetType);
    }    


    /*
     * Test to verify variuos SetType Method to test for has Attachment
     */  
    @isTest
    private static void verifySetTypeMethodsTest2_Attachment() 
    {
        system.debug('*** verifySetTypeMethodsTest() - START ***');
        
        Set<String> setType1 = new Set<String>();
        setType1.add(ConstantsActivityTimeline.SET_TYPE_TASK);
        setType1.add(ConstantsActivityTimeline.SET_TYPE_CALL);
        setType1.add(ConstantsActivityTimeline.SET_TYPE_HAS_ATTACHMENT);
        
        Boolean isTaskSetType = ActivityTimelineUtility.isTaskSetType(setType1);
        system.assertEquals(true, isTaskSetType);
        
        Boolean isEventSetType = ActivityTimelineUtility.isEventSetType(setType1);
        system.assertEquals(false, isEventSetType);
        
        Boolean isAttachmentSetType = ActivityTimelineUtility.isHasAttachmentSetType(setType1);
        system.assertEquals(true, isAttachmentSetType);
    }    

    
    
    /*
     * public static boolean isTaskOnlySetType(Task objTask, Set<String> setType)
     */  
    @isTest
    private static void isTaskOnlySetTypeTest() 
    {
        system.debug('*** isTaskOnlySetTypeTest() - START ***');
        
        Set<String> setType1 = new Set<String>();
        setType1.add(ConstantsActivityTimeline.SET_TYPE_TASK);
        
        // Let's create a Profile record (Person Account)
        Test.startTest();
        Account testAcct = [SELECT Id, Name, isPersonAccount FROM Account WHERE Name='Mickey Mouse' LIMIT 1];
        system.debug('111 testAcct=' + testAcct);
        
        DateTime currentDateTime = DateTime.now();
        
        List<Task> tasksToInsert = new List<Task>();
        Task testTask = createTestTask('Test Task 1', WMC_Constants.TASK_STATUS_NOT_STARTED, 
                                       testAcct.Id, false, false, 
                                       currentDateTime.date().addDays(2), 'Follow Up', 'Task', TASK_RECORD_TYPE);
        
        Task testTaskDoc = createTestTask('Test Task Doc', WMC_Constants.TASK_STATUS_NOT_STARTED, 
                                       testAcct.Id, false, false, 
                                       currentDateTime.date().addDays(5), 'Document', 'Task', DOC_RECORD_TYPE);
        
        tasksToInsert.add(testTask);
        tasksToInsert.add(testTaskDoc);
        
        insert tasksToInsert;
        
        Test.stopTest();

        Boolean isTaskOnly = ActivityTimelineUtility.isTaskOnlySetType(testTask, setType1);
        Boolean isTaskDoc = ActivityTimelineUtility.isTaskOnlySetType(testTaskDoc, setType1);
        
        system.assertEquals(true, isTaskOnly);
        system.assertEquals(false, isTaskDoc);
    }    


    /*
     * public static boolean isTaskOrCall(Task objTask, Set<String> setType)
     */  
    @isTest
    private static void isTaskOrCallTest() 
    {
        system.debug('*** isTaskOnlySetTypeTest() - START ***');
        
        Set<String> setType1 = new Set<String>();
        setType1.add(ConstantsActivityTimeline.SET_TYPE_TASK);
        
        // Let's create a Profile record (Person Account)
        Test.startTest();
        Account testAcct = [SELECT Id, Name, isPersonAccount FROM Account WHERE Name='Mickey Mouse' LIMIT 1];
        system.debug('111 testAcct=' + testAcct);
        
        DateTime currentDateTime = DateTime.now();
        
        List<Task> tasksToInsert = new List<Task>();
        Task testTask = createTestTask('Test Task 1', WMC_Constants.TASK_STATUS_NOT_STARTED, 
                                       testAcct.Id, false, false, 
                                       currentDateTime.date().addDays(2), 'Follow Up', 'Task', TASK_RECORD_TYPE);
        
        Task testTaskDoc = createTestTask('Test Task Doc', WMC_Constants.TASK_STATUS_NOT_STARTED, 
                                       testAcct.Id, false, false, 
                                       currentDateTime.date().addDays(5), 'Document', 'Task', DOC_RECORD_TYPE);
        
        tasksToInsert.add(testTask);
        tasksToInsert.add(testTaskDoc);
        
        insert tasksToInsert;
        
        Test.stopTest();

        Boolean isTaskOnly = ActivityTimelineUtility.isTaskOrCall(testTask, setType1);
        Boolean isTaskDoc = ActivityTimelineUtility.isTaskOrCall(testTaskDoc, setType1);
        
        system.assertEquals(true, isTaskOnly);
        system.assertEquals(false, isTaskDoc);
    }    


    /*
     * public static boolean isTaskDocument(Task objTask, Set<String> setType)
     */  
    @isTest
    private static void isTaskDocumentTest() 
    {
        system.debug('*** isTaskDocumentTest() - START ***');
        
        Set<String> setType1 = new Set<String>();
        setType1.add(ConstantsActivityTimeline.SET_TYPE_TASK);
        setType1.add(ConstantsActivityTimeline.SET_TYPE_DOCUMENT);
        
        // Let's create a Profile record (Person Account)
        Test.startTest();
        Account testAcct = [SELECT Id, Name, isPersonAccount FROM Account WHERE Name='Mickey Mouse' LIMIT 1];
        system.debug('111 testAcct=' + testAcct);
        
        DateTime currentDateTime = DateTime.now();
        
        List<Task> tasksToInsert = new List<Task>();
        Task testTask = createTestTask('Test Task 1', WMC_Constants.TASK_STATUS_NOT_STARTED, 
                                       testAcct.Id, false, false, 
                                       currentDateTime.date().addDays(2), 'Follow Up', 'Task', TASK_RECORD_TYPE);
        
        Task testTaskDoc = createTestTask('Test Task Doc', WMC_Constants.TASK_STATUS_NOT_STARTED, 
                                       testAcct.Id, false, false, 
                                       currentDateTime.date().addDays(5), 'Document', 'Task', DOC_RECORD_TYPE);
        
        tasksToInsert.add(testTask);
        tasksToInsert.add(testTaskDoc);
        
        insert tasksToInsert;
        
        Test.stopTest();

        Boolean isTaskOnly = ActivityTimelineUtility.isTaskDocument(testTask, setType1);
        Boolean isTaskDoc = ActivityTimelineUtility.isTaskDocument(testTaskDoc, setType1);
        
        system.assertEquals(false, isTaskOnly);
        system.assertEquals(true, isTaskDoc);
    }    


    /*
     * public static boolean isTaskLogACall(Task objTask, Set<String> setType)
     */  
    @isTest
    private static void isTaskLogACallTest() 
    {
        system.debug('*** isTaskLogACallTest() - START ***');
        
        Set<String> setType1 = new Set<String>();
        setType1.add(ConstantsActivityTimeline.SET_TYPE_TASK);
        setType1.add(ConstantsActivityTimeline.SET_TYPE_CALL);
        
        // Let's create a Profile record (Person Account)
        Test.startTest();
        Account testAcct = [SELECT Id, Name, isPersonAccount FROM Account WHERE Name='Mickey Mouse' LIMIT 1];
        system.debug('111 testAcct=' + testAcct);
        
        DateTime currentDateTime = DateTime.now();
        
        List<Task> tasksToInsert = new List<Task>();
        Task testTaskCall = createTestTask('Test Task 1', WMC_Constants.TASK_STATUS_NOT_STARTED, 
                                           testAcct.Id, false, false, 
                                           currentDateTime.date().addDays(2), 'Call', 
                                           ConstantsActivityTimeline.TASK_SUBTYPE_CALL, TASK_RECORD_TYPE);
        
        Task testTaskDoc = createTestTask('Test Task Doc', WMC_Constants.TASK_STATUS_NOT_STARTED, 
                                       testAcct.Id, false, false, 
                                       currentDateTime.date().addDays(5), 'Document', 'Task', DOC_RECORD_TYPE);
        
        tasksToInsert.add(testTaskCall);
        tasksToInsert.add(testTaskDoc);
        
        insert tasksToInsert;
        
        Test.stopTest();

        Boolean isCallOnly = ActivityTimelineUtility.isTaskLogACall(testTaskCall, setType1);
        Boolean isTaskDoc = ActivityTimelineUtility.isTaskLogACall(testTaskDoc, setType1);
        
        system.assertEquals(true, isCallOnly);
        system.assertEquals(false, isTaskDoc);
    }

    
    /*
     * public static String getDateFilterConverted(String dateFilter)
     */  
    @isTest
    private static void getDateFilterConvertedTest() 
    {
        system.debug('*** getDateFilterConvertedTest() - START ***');
        
        String dateFilter_One = ActivityTimelineUtility.getDateFilterConverted(ConstantsActivityTimeline.ONE);
        system.assertEquals(ConstantsActivityTimeline.LAST_THIRTY_DAYS, dateFilter_One);

        String dateFilter_3Years = ActivityTimelineUtility.getDateFilterConverted(ConstantsActivityTimeline.THREE_YEARS);
        system.assertEquals(ConstantsActivityTimeline.LAST_THREE_YEARS, dateFilter_3Years);

        String dateFilter_Bad = ActivityTimelineUtility.getDateFilterConverted('Bad');
        system.assertEquals('', dateFilter_Bad);
    }


    /*
     * public static String getDateFilterQuery(Date activityDateFilter, Date startDate, 
     *   Date endDate, Boolean isDueDate, String dateFieldName, Boolean dayOnly)
     *
     */  
    @isTest
    private static void getDateFilterQueryTest() 
    {
        system.debug('*** getDateFilterQueryTest() - START ***');
        
        // Generic used in query
        Date startDate = Date.newInstance(2010, 12, 20);
        Date endDate = Date.newInstance(2010, 12, 30);

        
        try
        {
            Date startDate1 = Date.newInstance(2010, 12, 20);
            Date endDate1 = Date.newInstance(2010, 12, 26);
            String dateFilterQuery1 = ActivityTimelineUtility.getDateFilterQuery(null, startDate1, endDate1, true, 
                                                                 'ActivityDate', true);
    
            // Use the filter in a query
            String taskQuery1 = 'SELECT Id, Subject FROM Task WHERE Subject != NULL ' + dateFilterQuery1;
            system.debug('getDateFilterQueryTest() --> taskQuery1=' + taskQuery1);
            List<Task> tasks1 = Database.query(taskQuery1);
            system.assert( tasks1 != null );

            
            Date startDate2 = Date.newInstance(2010, 12, 20);
            Date endDate2 = Date.newInstance(2010, 12, 20);
            String dateFilterQuery2 = ActivityTimelineUtility.getDateFilterQuery(null, startDate2, endDate2, true, 
                                                                 'ActivityDate', true);
            String dateFilterQuery2b = ActivityTimelineUtility.getDateFilterQuery(null, startDate2, null, true, 
                                                                 'ActivityDate', true);
    
            // Use the filter in a query
            String taskQuery2 = 'SELECT Id, Subject FROM Task WHERE Subject != NULL ' + dateFilterQuery2;
            system.debug('getDateFilterQueryTest() --> taskQuery2=' + taskQuery2);
            List<Task> tasks2 = Database.query(taskQuery2);
            system.assert( tasks2 != null );
            
            Date startDate3 = Date.newInstance(2010, 12, 20);
            Date endDate3 = Date.newInstance(2010, 12, 20);
            String dateFilterQuery3 = ActivityTimelineUtility.getDateFilterQuery(null, startDate3, endDate3, false, 
                                                                 'ActivityDate', false);
    
            // Use the filter in a query
            String taskQuery3 = 'SELECT Id, Subject FROM Task WHERE Subject != NULL ' + dateFilterQuery3;
            system.debug('getDateFilterQueryTest() --> taskQuery3=' + taskQuery3);
            List<Task> tasks3 = Database.query(taskQuery3);
            system.assert( tasks3 != null );

            Date startDate4 = Date.newInstance(2010, 12, 20);
            Date endDate4 = Date.newInstance(2010, 12, 23);
            String dateFilterQuery4 = ActivityTimelineUtility.getDateFilterQuery(null, startDate4, endDate4, false, 
                                                                 'ActivityDate', false);
    
            // Use the filter in a query
            String taskQuery4 = 'SELECT Id, Subject FROM Task WHERE Subject != NULL ' + dateFilterQuery4;
            system.debug('getDateFilterQueryTest() --> taskQuery4=' + taskQuery4);
            List<Task> tasks4 = Database.query(taskQuery4);
            system.assert( tasks4 != null );
            
            Date startDate5 = Date.newInstance(2010, 12, 20);
            Date endDate5 = Date.newInstance(2010, 12, 20);
            Date endDate5b = Date.newInstance(2010, 12, 23);
            String dateFilterQuery5 = ActivityTimelineUtility.getDateFilterQuery(null, startDate5, endDate5, true, 
                                                                 'ActivityDate', false);
            String dateFilterQuery5b = ActivityTimelineUtility.getDateFilterQuery(null, startDate5, endDate5b, true, 
                                                                 'ActivityDate', false);
    
            // Use the filter in a query
            String taskQuery5 = 'SELECT Id, Subject FROM Task WHERE Subject != NULL ' + dateFilterQuery5;
            system.debug('getDateFilterQueryTest() --> taskQuery5=' + taskQuery5);
            List<Task> tasks5 = Database.query(taskQuery5);
            system.assert( tasks5 != null );
            
            Date startDate6 = Date.newInstance(2010, 12, 20);
            Date endDate6 = null;
            String dateFilterQuery6 = ActivityTimelineUtility.getDateFilterQuery(null, startDate6, endDate6, true, 
                                                                 'ActivityDate', false);
    
            // Use the filter in a query
            String taskQuery6 = 'SELECT Id, Subject FROM Task WHERE Subject != NULL ' + dateFilterQuery6;
            system.debug('getDateFilterQueryTest() --> taskQuery6=' + taskQuery6);
            List<Task> tasks6 = Database.query(taskQuery6);
            system.assert( tasks6 != null );

        }
        catch (Exception e)
        {
            system.debug('ERROR - getDateFilterQueryTest: ' + e.getMessage() );
            system.assert(false, 'ERROR: Should not hit exception');
        }
    }    

    
    
    /*
     *  Test the child object TaskEventEmailRelatedInfo (constructor)
     * 
     * public TaskEventEmailRelatedInfo(String recordId, boolean hasAttachments)
     */  
    @isTest
    private static void constructorForTaskEventEmailRelatedInfoTest() 
    {
        // Let's create a Profile record (Person Account)
        Test.startTest();
        Account testAcct = [SELECT Id, Name, isPersonAccount FROM Account WHERE Name='Mickey Mouse' LIMIT 1];
        system.debug('111 testAcct=' + testAcct);
        Test.stopTest();
        
        List<String> categories = new List<String>();
        categories.add('AAAAA');
        categories.add('BBBBB');
        categories.add('CCCCC');
        ActivityTimelineUtility.TaskEventEmailRelatedInfo relatedInfo 
            			= new ActivityTimelineUtility.TaskEventEmailRelatedInfo(testAcct.Id, false);
        
        relatedInfo.categories = categories;
        system.assertEquals(false, relatedInfo.hasAttachments);
        system.assertEquals('AAAAA,BBBBB,CCCCC', relatedInfo.getTagString() );
    }    
    
    
    
    /*
     *  Test the child object ActivityIdSetObj (constructor)
     */  
    @isTest
    private static void constructorForActivityIdSetObjTest() 
    {
        // Let's create a Profile record (Person Account)
        Test.startTest();
        Account testAcct = [SELECT Id, Name, isPersonAccount FROM Account WHERE Name='Mickey Mouse' LIMIT 1];
        system.debug('111 testAcct=' + testAcct);
        Test.stopTest();
        
        ActivityTimelineUtility.ActivityIdSetObj idSetObj = new ActivityTimelineUtility.ActivityIdSetObj(testAcct.Id);
        
        system.assert(true, idSetObj.whatIdSet.contains(testAcct.Id) );
    }    
    
    
    
    //*****************************************************************************************
    //     HELPER METHODS
    //*****************************************************************************************

    /*
     * Create test Profile record (Individual record type)
     */
    private static Account createTestIndividualProfile(String tmpFirstName, String tmpLastName)
    {
        Account testAcct = new Account(LastName = tmpLastName, FirstName = tmpFirstName, FinServ__Status__c = ConstantsActivityTimeline.STATUS_PROSPECT,
                                       PersonEmail = tmpFirstName + '.' + tmpLastName + '@test.ca',
                                       RecordTypeId = WMC_TestFactory.individualRecordTypeId );
        return testAcct;
    }


    /*
     * Create test Profile record (Household)
     */
    private static Account createTestHouseholdProfile(String householdName)
    {
        Account testAcct = new Account(Name = householdName, FinServ__Status__c = ConstantsActivityTimeline.STATUS_PROSPECT,
                                       RecordTypeId = WMC_TestFactory.householdRecordTypeId );
        return testAcct;
    }


    /*
     * Create test Profile record (Company)
     */
    private static Account createTestCompanyProfile(String companyName)
    {
        Account testAcct = new Account(Name = companyName, 
                                       FinServ__Status__c = ConstantsActivityTimeline.STATUS_PROSPECT,
                                       Organization_Legal_Name_1__c = companyName,
                                       RecordTypeId = WMC_TestFactory.companyRecordTypeId );
        return testAcct;
    }
    
    
    /*
     * Create ACR
     */  
    private static AccountContactRelation createTestACR(Id accountId, id contactId, Boolean primaryMember, 
                                                        Boolean primaryGroup, String role)
    {
		AccountContactRelation acr = new AccountContactRelation();
        acr.AccountId = accountId;
        acr.ContactId = contactId;
        acr.FinServ__Primary__c = primaryMember;
        acr.FinServ__PrimaryGroup__c = primaryGroup;
        acr.Roles = role;
        acr.FinServ__Rollups__c = 'All';
        
        return acr;
    }


	/*
	 * Create Test Event record
	 */  
	public static Event createTestEvent(String subject, Id whoId, id whatId, Boolean phonecall, Boolean review,
                                         DateTime startDateTime)
    {	
        Event e = new Event();
        e.Subject = subject;
        e.RecordTypeId = EVENT_RECORD_TYPE;
        e.whoid = whoId;
        e.whatid = whatId;
        e.Phone_Call__c = phoneCall;
        e.Review__c = review;
        e.StartDateTime = startDateTime;
        e.EndDateTime = startDateTime.addHours(1);
        e.ActivityDate = startDateTime.date();
        
        return e;
    }
    
    
    /*
     * Create Test Task
     */  
    public static Task createTestTask(String subject, String status, id whatId, Boolean phoneCall, Boolean review, Date dueDate,
                                       String taskType, String taskSubType, id recordTypeId)
    {
        Task t = new Task();
        t.RecordTypeId = recordTypeId;
        t.whatId = whatId;
        t.Type = taskType;
        t.TaskSubType = taskSubType;
        t.Phone_Call__c = phoneCall;
        t.Review__c = review;
        t.Priority = ConstantsActivityTimeline.PRIORITY_A;
        t.Status = status;  
        t.Subject = subject;
        t.ActivityDate = dueDate;
        t.CV_Unique_Key__c = subject + '-' + Integer.valueof((Math.random() * 10));
        t.Notes__c = 'Test';
        t.Description = 'Test';
      	return t;  
    }
    
    /*
     * Create test IER's
     */  
    private static et4ae5__IndividualEmailResult__c createTestIERs(String subject, Id personContactId)
    {
        List<et4ae5__SendDefinition__c> individualEmailSendResults = new List<et4ae5__SendDefinition__c>();
        individualEmailSendResults.add(new et4ae5__SendDefinition__c(et4ae5__Contact__c=personContactId));
        insert individualEmailSendResults;
        
		et4ae5__IndividualEmailResult__c ier = new et4ae5__IndividualEmailResult__c();
        ier.Name = subject;
        ier.et4ae5__Contact__c=personContactId;
        ier.et4ae5__SendDefinition__c=individualEmailSendResults[0].Id;
        ier.Updated_with_Custom_Values__c=true;
        ier.et4ae5__SubjectLine__c= subject;
        ier.et4ae5__DateSent__c = system.now().addDays(-10);
        
        return ier;
    }

    /*
     * Create Test Attachments
     */  
    private static Document_Management__c createTestAttachment(String relatedId, String fileName, String fileType,
                                                               String filePath, String crmOid, DateTime uploadDateTime)
    {
        Document_Management__c dm = new Document_Management__c();
        dm.Related_Record_Id__c = relatedId;
        dm.Crm_Oid__c = crmOid;
        dm.Deleted__c = false;
        dm.File_Name__c = fileName;
        dm.File_Size__c = 300;
        dm.File_Path__c = filePath;
        dm.File_Type__c = fileType;
        dm.sObject__c = 'Account';
        dm.Uploaded_By__c = 'Jane Doe';
        dm.UploadedDate__c = uploadDateTime;
        
        return dm;
    }
 
    
    
    /**
     * Create Test EmailMessage record
     */  
    public static EmailMessage createTestEmailMessage(String fromEmail, String toEmail, String subject, String emailBody, 
                                                      Id relatedId, Integer numCreatedDays)
    {
        DateTime sendDate = DateTime.now().addDays(numCreatedDays);
    	EmailMessage testEmail = new EmailMessage();
        testEmail.Subject = subject;
        testEmail.FromAddress = fromEmail;
        testEmail.ToAddress = toEmail;
        testEmail.TextBody = emailBody;
        testEmail.RelatedToId  = relatedId;
        testEmail.MessageDate = sendDate;
        testEmail.Status = '5'; // DRAFT
        testEmail.CreatedDate = sendDate;
        return testEmail;
    }    

    
    
    /**
     * Create a test EmailMessageRelation record
     */  
    public static EmailMessageRelation createTestEmailMessageRelation(String relationAddress, String relatedId, 
                                                                      String relationType, id emailMessageId)
    {
    	EmailMessageRelation emr = new EmailMessageRelation();
        emr.EmailMessageId = emailMessageId;
        emr.RelationType = relationType;
        
        if ( relatedId != null )
        {
            emr.RelationId = relatedId;
        }
        
        if ( relationAddress != null )
        {
            emr.RelationAddress = relationAddress;
        }
        
        return emr;
    }    
}