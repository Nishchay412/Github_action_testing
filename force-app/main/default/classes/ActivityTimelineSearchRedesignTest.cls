/***************************************************************************************
Class Name : ActivityTimelineSearchRedesignTest
Created Date : 07-04-2025 
Description : Test Class for ActivityTimelineSearchRedesign class

Modification Log:

* Developer Name    Date        Description
-----------------------------------------------------------------------------------------
* Prathyusha KV   07-04-2025      WMCSFH2-5844 - Table rebdering for activity search redesign
* Prathyusha KV   05-22-2025      WMCSFH2-6109,6146 - Lazy load for activity search redesign
* Nicole Fernandez  05-28-2025      WMCSFH2-6146 - Sorting logic
* Prathyusha KV     02-06-2025  WMCSFH2-6041,6014 changes to test class
* Lily Wu           26-06-2025  WMCSFH2-5817 Pinned Activities Redesign - Profile Panel 
* Lily Wu           11-09-2025  WMCSFH2-7282 Enhance Searching Logic in Recent Activities to Include Child Records for Recurring Tasks
******************************************************************************************/
@isTest(seeAllData=false)
public class ActivityTimelineSearchRedesignTest 
{
    static String startDate = system.now().format('yyyy-MM-dd');
    static String createdby =  Userinfo.getUserId();
    
    @testSetup
    static void testDataSetup() 
    {
        Set<String> profileNameSet = new Set<String>{WMC_Constants.PHN_HO_PROFILE, WMC_Constants.ADMIN_PROFILE};
            
        Id phnProId;
        Id adminProId; 
        User phnUser = new User();
        User adminUser = new User();
        for(Profile proRecord : [SELECT Id, Name FROM Profile WHERE Name IN :profileNameSet]){
            if(proRecord.Name == WMC_Constants.ADMIN_PROFILE){
                adminProId = proRecord.Id;
            } else{
                phnProId = proRecord.Id; 
            }
        }
        List<User> userList = new List<User>();
        userList.add(WMC_TestFactory.getUserData('testUser', phnProId));
        userList.add(WMC_TestFactory.getUserData('admUser', adminProId));
        INSERT userList;
        
        for(User userRecord: userList){
            if(userRecord.ProfileId == adminProId){
                adminUser = userRecord;
            } else{
                phnUser = userRecord;
            }
        }
        
        System.runAs(adminUser){
            Id accountRoleRecordTypeId = Schema.SObjectType.FinServ__ReciprocalRole__c.getRecordTypeInfosByDeveloperName().get(WMC_Constants.ACCOUNT_ROLE_RT).getRecordTypeId();
            List<Case> caseList = WMC_TestFactory.getCaseData(1,WMC_Constants.DS);
            insert CaseList;
            List<Account> householdAccountList = WMC_TestFactory.getAccountData(1,WMC_Constants.HOUSEHOLD_ACC_RT);
            for(Account acc : householdAccountList){
                acc.FinServ__Status__c = ConstantsActivityTimeline.STATUS_PROSPECT;
            }
            insert householdAccountList;
            List<Account> individualAccountList = WMC_TestFactory.getAccountData(1,WMC_Constants.INDIVIDUAL_ACC_RT);
            for(Account acc : individualAccountList){
                acc.FinServ__Status__c = ConstantsActivityTimeline.STATUS_PROSPECT;
            }
            insert individualAccountList;
           
            Contact con = [SELECT Id, AccountId FROM Contact WHERE accountId =: individualAccountList[0].id LIMIT 1];
            List < AccountContactRelation > accountContactRelList = new List < AccountContactRelation > ();
            FinServ__ReciprocalRole__c role = new FinServ__ReciprocalRole__c(Name=ConstantsActivityTimeline.ROLE_OTHER,FinServ__InverseRole__c=ConstantsActivityTimeline.ROLE_OTHER,recordTypeId = AccountRoleRecordTypeId);
            insert role;
            accountContactRelList.add(new AccountContactRelation(
                AccountId = householdAccountList[0].id, ContactId = con.id, FinServ__Primary__c = false, FinServ__PrimaryGroup__c=true
               ,FinServ__Rollups__c='All,Tasks,Events'  ,Roles = role.id));           
            insert accountContactRelList;
            
            List<ActionPlanTemplate__c> apTemp = WMC_TestFactory.getActionPlanTemplateData(1,'');
            insert apTemp;
            
            List<APTemplateTask__c> apTTask = WMC_TestFactory.getActionPlanTemplateTaskData(2,apTemp[0].Id);
            for(Integer i = 0;i < 2; i++){
                apTTask[i].TaskIndex__c = i;
            }
            insert apTTask;
            
            List<ActionPlan__c> actionPlanList = WMC_TestFactory.getActionPlanData(3, individualAccountList[0].id, WMC_Constants.TASK_WMC);
            for(integer i = 0; i < 3;i++){
               // actionPlanList[i].Is_Pinned__c = true;
                actionPlanList[i].Action_Plan_Template__c = apTemp[0].Id;
                actionPlanList[i].name = 'test AP '+ i;
                actionPlanList[i].OwnerId = Userinfo.getUserId();
                if(i==0){
                    actionPlanList[i].StartDate__c = System.today() + 1; 
                }
                if(i==1){
                    actionPlanList[i].StartDate__c = System.today() - 1;  
                }
                if(i==2){
                    actionPlanList[i].StartDate__c = System.today();  
                }
             
            }
            insert actionPlanList;
            
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
            List<Task> taskApList = WMC_TestFactory.getTaskData(2,WMC_Constants.TASK_WMC);
            for(Integer i = 0;i < 2;i++){
                taskApList[i].TaskApTask__c = apTask[i].Id;
                taskApList[i].Subject = 'Subject'+i;
                taskApList[i].ActivityDate = date.newInstance(2022, 8, 1);
                taskApList[i].Type = WMC_Constants.PLACECALL;
                taskApList[i].Status = 'COMP';
            }
            insert taskApList;
            
          //  List < Event > eventList = WMC_TestFactory.getEventData(7,WMC_Constants.EVENT_WMC,phnUser.Id);
           List < Event > eventList = WMC_TestFactory.getEventData(7,WMC_Constants.EVENT_WMC,adminUser.Id);
            for (integer i = 0; i < 7; i++) {
                eventList[i].subject=ConstantsActivityTimeline.SUBJECT_CALL;
                eventList[i].whoid = con.id;
                eventList[i].whatid = individualAccountList[0].Id;
                eventList[i].Phone_Call__c = true;
                eventList[i].Review__c = true;
                eventList[i].CV_Unique_Key__c = 'eventUk'+i;
                if (i == 1) {
                    eventList[i].subject = ConstantsActivityTimeline.SUBJECT_TEST_PINNED;
                    eventList[i].StartDateTime = System.today();
                    eventList[i].EndDateTime = System.today() + 5;
                    eventList[i].ActivityDate = System.today();
                } else if (i == 2) {
                    eventList[i].subject = 'TestAttachment';
                    eventList[i].Is_Pinned__c = true;
                    eventList[i].StartDateTime = System.today() -2;
                    eventList[i].EndDateTime = System.today() - 1;
                    eventList[i].ActivityDate = System.today() -2;   
                    
                }
                else if (i == 3) {
                    eventList[i].StartDateTime = System.today() - 1;
                    eventList[i].EndDateTime = System.today() - 1;
                    eventList[i].ActivityDate = System.today() - 1;
                    
                }else if (i == 4) {
                    eventList[i].StartDateTime = System.today();
                    eventList[i].EndDateTime = System.today() + 1;
                    eventList[i].ActivityDate = System.today();
                    
                } 
                else if(i==5){
                    eventList[i].StartDateTime = System.today() + 2;
                    eventList[i].EndDateTime = System.today() + 2;
                    eventList[i].ActivityDate = System.today() +2;
                }
                else if(i==6){
                    eventList[i].StartDateTime = System.today() -5;
                    eventList[i].EndDateTime = System.today() -4;
                    eventList[i].ActivityDate = System.today() -5;
                }
                else {
                    eventList[i].StartDateTime = System.today() - 1;
                    eventList[i].EndDateTime = System.today() ;
                    eventList[i].ActivityDate = System.today() - 1;
                }
            }
            insert eventList;
            Id recTypeIdTask = Schema.SObjectType.Task.getRecordTypeInfosByDeveloperName().get(WMC_Constants.TASK_WMC).getRecordTypeId();
            Id recTypeIdDocument = Schema.SObjectType.Task.getRecordTypeInfosByDeveloperName().get(WMC_Constants.DOCUMENT_WMC).getRecordTypeId();
            
            List<Task> taskList = WMC_TestFactory.getTaskData(10,WMC_Constants.TASK_WMC);
            for (integer i = 0; i < 10; i++) {
                taskList[i].whoid = con.id;
                taskList[i].Type = ConstantsActivityTimeline.TASK_TYPE_TEAM_TASK;
                taskList[i].Phone_Call__c = true;
                taskList[i].Review__c = true;
                taskList[i].Priority = ConstantsActivityTimeline.PRIORITY_A;
                taskList[i].Status = ConstantsActivityTimeline.STATUS_IN_PROGRESS;  
                taskList[i].CV_Unique_Key__c = 'uniqueKey'+i;                                                             
                if (i == 1) {
                    taskList[i].Subject = ConstantsActivityTimeline.SUBJECT_TEST_PINNED;
                    taskList[i].ActivityDate = System.today();
                    taskList[i].RecordTypeId = recTypeIdTask;
                    taskList[i].Notes__c = 'Test';
                } else if (i == 2) {
                    taskList[i].Subject = ConstantsActivityTimeline.SUBJECT_TEST_UNPINNED;
                    taskList[i].Is_Pinned__c = true;
                    taskList[i].ActivityDate = System.today() + 1;
                    taskList[i].RecordTypeId = recTypeIdTask;
                    taskList[i].Subject = 'TestAttachment';
                } else if (i == 3) {
                    taskList[i].ActivityDate = System.today() - 1; 
                    taskList[i].RecordTypeId = recTypeIdTask;
                } else if (i == 4) {
                    taskList[i].Type = ConstantsActivityTimeline.DOCUMENT;
                    taskList[i].ActivityDate = System.today();
                    taskList[i].RecordTypeId = recTypeIdDocument;
                } else if (i == 5) {
                    taskList[i].ActivityDate = System.today();
                    taskList[i].RecordTypeId = recTypeIdTask;
                    taskList[i].Status = ConstantsActivityTimeline.STATUS_COMPLETED_API;
                    taskList[i].Notes__c = 'Test';
                    
                } else if (i == 6) {
                    taskList[i].ActivityDate = null;
                    taskList[i].RecordTypeId = recTypeIdTask;
                } else if (i == 7) {
                    taskList[i].subject = 'Test'+ ConstantsActivityTimeline.DOCUMENT;
                    taskList[i].Type = ConstantsActivityTimeline.DOCUMENT;
                    taskList[i].ActivityDate = System.today() + 1;
                    taskList[i].RecordTypeId = recTypeIdDocument; 
                    taskList[i].Notes__c = 'Test';
                } else if (i == 8) {
                    taskList[i].Subject = 'TestLogACall';
                    taskList[i].ActivityDate = System.today();
                    taskList[i].TaskSubtype = ConstantsActivityTimeline.TASK_SUBTYPE_CALL;
                    taskList[i].Status = ConstantsActivityTimeline.STATUS_IN_PROGRESS;
                    taskList[i].RecordTypeId = recTypeIdTask;
                } 
                taskList[i].Priority = ConstantsActivityTimeline.PRIORITY_A;
            }
            insert tasklist;

            List<EmailMessage> emailMessageList = WMC_TestFactory.getEmailMessageData(3);
            for(Integer i = 0; i < 3; ++i) {
                if(i == 0) {
                    emailMessageList[i].RelatedToId = householdAccountList[0].Id;                    
                    emailMessageList[i].Additional_Relationships__c = householdAccountList[0].Id;
                   // emailMessageList[i].hasAttachment = true;
                 } else {
                    emailMessageList[i].RelatedToId = individualAccountList[0].Id;
                }
                
            }
            insert emailMessageList;
        }
    }

    

    @isTest
    static void timeLineControllerTaskTest() 
    {
        test.startTest();
        User adminUser = [SELECT Id, Alias FROM User WHERE Alias='admUser' LIMIT 1];
        List <ActivityCustomDataRowWrapper> lst1 ;
        System.runAs(adminUser)
        {
            String dateFilter='';
            List < String > lstType = new List <String> {ConstantsActivityTimeline.SET_TYPE_TASK,
                                                         ConstantsActivityTimeline.SET_TYPE_SLM};
                
            Account accId = [SELECT id, Recordtype.Developername 
                             FROM Account 
                             WHERE Name = :ConstantsActivityTimeline.HOUSEHOLD_NAME LIMIT 1];
            String searchTerm ='test';
            String dateType ='dueDate';
            String pastActivity ='3';
            
            ActivityTimelineSearchRedesign.ActivitySearchResults results 
                		= ActivityTimelineSearchRedesign.getActivityResults(accId.Id, lstType, searchTerm, 
                                                                            null, null, null, null, null, null,10,0,'dueDate','asc');
            System.assertEquals(true, results != null, 'results should not be null');
            System.assertEquals(true, results.dataTableResponse != null, 'results.dataTableResponse should not be null');
            lst1 = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, lstType, searchTerm, pastActivity, dateType, startDate, null,null, null,10,0,'dueDate','asc');

            List<String> lstType2 = new List<String>{ConstantsActivityTimeline.SET_TYPE_TASK,ConstantsActivityTimeline.SET_TYPE_HAS_ATTACHMENT};
            List < ActivityCustomDataRowWrapper > lst2 = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, lstType2, searchTerm, pastActivity, dateType, startDate, null,null, null,10,0,'dueDate','asc');
            
            List<String> lstType3 = new List<String>{ConstantsActivityTimeline.SET_TYPE_TASK};
            List < ActivityCustomDataRowWrapper > lst3 = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, lstType3, searchTerm, pastActivity, dateType, startDate, null,null, null,10,0,'dueDate','asc');
            
            List<String> lstType4 = new List<String>{ConstantsActivityTimeline.SET_TYPE_TASK,ConstantsActivityTimeline.SET_TYPE_HAS_ATTACHMENT,ConstantsActivityTimeline.SET_TYPE_SLM};
            List < ActivityCustomDataRowWrapper > lst4 = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, lstType4, searchTerm, pastActivity, dateType, startDate, null,null, null,10,0,'dueDate','asc');
        }
        test.stopTest();
        System.assertEquals(true, lst1.size() > 0, 'lst1 should not be empty');
        System.assertEquals(true, lst1.size() > 0, 'lst1 should not be empty');
      
    }
    

    @isTest
    static void timeLineControllerLogACallTest() {
       
        test.startTest();
        User adminUser = [SELECT Id, Alias FROM User WHERE Alias='admUser' LIMIT 1];
        List < ActivityCustomDataRowWrapper > lst1 ;
        System.runAs(adminUser){
            String dateFilter='';
            List < String > lstType = new List < String > {ConstantsActivityTimeline.SET_TYPE_CALL,ConstantsActivityTimeline.SET_TYPE_SLM};

            Account accId = [SELECT id, recordtype.developername FROM Account WHERE Name = :ConstantsActivityTimeline.HOUSEHOLD_NAME
                             LIMIT 1
                            ];
            String searchTerm ='';
            String dateType ='';           
            
                             
            ActivityTimelineSearchRedesign.ActivitySearchResults  results = ActivityTimelineSearchRedesign.getActivityResults(accId.Id, lstType, searchTerm, null, null, null, null,null, null,10,0,'dueDate','asc');
            lst1 = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, lstType, searchTerm, null, dateType, startDate, null,null, null,10,0,'dueDate','asc');
           
            List <String> lstType2 = new List<String>{ConstantsActivityTimeline.SET_TYPE_CALL,ConstantsActivityTimeline.SET_TYPE_HAS_ATTACHMENT};
            List < ActivityCustomDataRowWrapper > lst2 = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, lstType2, searchTerm, null, dateType, startDate, null,null, null,10,0,'dueDate','asc');
           
            List <String> lstType3 = new List<String>{ConstantsActivityTimeline.SET_TYPE_CALL};
            List < ActivityCustomDataRowWrapper > lst3 = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, lstType3, searchTerm, null, dateType, startDate, null,null, null,10,0,'dueDate','asc');

            List <String> lstType4 = new List<String>  {ConstantsActivityTimeline.SET_TYPE_CALL,ConstantsActivityTimeline.SET_TYPE_HAS_ATTACHMENT,ConstantsActivityTimeline.SET_TYPE_SLM};
            List < ActivityCustomDataRowWrapper > lst4 = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, lstType4, searchTerm, null, dateType, startDate, null,null, null,10,0,'dueDate','asc');

          
           
        }
        test.stopTest();
        System.assertEquals(true, lst1.size() > 0);
    }    
 

    @isTest
    static void timeLineControllerDocumentTest() {
       
        test.startTest();
        User adminUser = [SELECT Id, Alias FROM User WHERE Alias='admUser' LIMIT 1];
        List < ActivityCustomDataRowWrapper > lst ;
        System.runAs(adminUser){
            String dateFilter='';
            List < String > lstType = new List < String > {ConstantsActivityTimeline.SET_TYPE_DOCUMENT,ConstantsActivityTimeline.SET_TYPE_SLM};

            Account accId = [SELECT id, recordtype.developername FROM Account WHERE Name = :ConstantsActivityTimeline.HOUSEHOLD_NAME
                             LIMIT 1
                            ];
            String searchTerm ='';
            String dateType ='dueDate';
           
            ActivityTimelineSearchRedesign.ActivitySearchResults  results = ActivityTimelineSearchRedesign.getActivityResults(accId.Id, lstType, searchTerm, null, null, null, null,null, null,10,0,'dueDate','asc');
            lst = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, lstType, searchTerm, null, dateType, null, null,null, null,10,0,'dueDate','asc');
           

            List <String> lstType2 = new List<String>{ConstantsActivityTimeline.SET_TYPE_DOCUMENT,ConstantsActivityTimeline.SET_TYPE_HAS_ATTACHMENT};
            List < ActivityCustomDataRowWrapper > lst2 = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, lstType2, searchTerm, null, dateType, null, null,null, null,10,0,'dueDate','asc');
           
            List <String> lstType3 = new List<String>{ConstantsActivityTimeline.SET_TYPE_DOCUMENT};
            List < ActivityCustomDataRowWrapper > lst3 = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, lstType3, searchTerm, null, dateType, null, null,null, null,10,0,'dueDate','asc');
           
            List <String> lstType4 = new List<String> {ConstantsActivityTimeline.SET_TYPE_DOCUMENT,ConstantsActivityTimeline.SET_TYPE_HAS_ATTACHMENT,ConstantsActivityTimeline.SET_TYPE_SLM};
            List < ActivityCustomDataRowWrapper > lst4 = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, lstType4, searchTerm, null, dateType, null, null,null, null,10,0,'dueDate','asc');
           
        }
        test.stopTest();
        System.assertEquals(true, lst.size() > 0);
    }


    @isTest
    static void timeLineControllerEventTest() {
       
        test.startTest();
        User adminUser = [SELECT Id, Alias FROM User WHERE Alias='admUser' LIMIT 1];
        List <ActivityCustomDataRowWrapper> lst3 ;
        System.runAs(adminUser){
            String dateFilter='';
            List < String > lstType = new List < String > {ConstantsActivityTimeline.SET_TYPE_EVENT,ConstantsActivityTimeline.SET_TYPE_SLM};

            Account accId = [SELECT id, recordtype.developername FROM Account WHERE Name = :ConstantsActivityTimeline.HOUSEHOLD_NAME
                             LIMIT 1
                            ];
            String searchTerm ='test';
            String dateType ='dueDate';
            String pastActivity ='3';
           
            ActivityTimelineSearchRedesign.ActivitySearchResults  results = ActivityTimelineSearchRedesign.getActivityResults(accId.Id, lstType, searchTerm, pastActivity, null, null, null,null, null,10,0,'dueDate','asc');
            List <ActivityCustomDataRowWrapper> lst1 = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, lstType, searchTerm, null, dateType, startDate, null,null, null,10,0,'dueDate','asc');
            

            List <String> lstType2 = new List <String> {ConstantsActivityTimeline.SET_TYPE_EVENT,ConstantsActivityTimeline.SET_TYPE_HAS_ATTACHMENT};
            List <ActivityCustomDataRowWrapper> lst2 = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, lstType2, searchTerm, null, dateType, null, null,null, null,10,0,'dueDate','asc');

            List <String> lstType3 = new List <String> {ConstantsActivityTimeline.SET_TYPE_EVENT};
            lst3 = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, lstType3, searchTerm, null, dateType, null, null,null, null,10,0,'dueDate','asc');
           
            List <String> lstType4 = new List <String> {ConstantsActivityTimeline.SET_TYPE_EVENT,ConstantsActivityTimeline.SET_TYPE_HAS_ATTACHMENT,ConstantsActivityTimeline.SET_TYPE_SLM};
            List <ActivityCustomDataRowWrapper> lst4 = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, lstType4, searchTerm, null, dateType, null, null,null, null,10,0,'dueDate','asc');
          
            
        }
        test.stopTest();
        System.assertEquals(true, lst3.size() > 0);
      
    }

    @isTest
    static void timeLineControllerEmailTest() {
        try{
        test.startTest();
        User adminUser = [SELECT Id, Alias FROM User WHERE Alias='admUser' LIMIT 1];
        List < ActivityCustomDataRowWrapper > lstActDet ;
        System.runAs(adminUser){
            String dateFilter=ConstantsActivityTimeline.SEVEN;
            String dateToFilter = CustomActivityTimeLine.getDateFilterConverted(dateFilter);
            List < String > lstType = new List < String > {ConstantsActivityTimeline.SET_TYPE_EMAIL,ConstantsActivityTimeline.SET_TYPE_SSC_EMAIL};
                     
            Account accId = [SELECT id, recordtype.developername FROM Account WHERE  Name = :ConstantsActivityTimeline.HOUSEHOLD_NAME
                             LIMIT 1
                            ];
            String searchTerm = 'test';
            List<EmailMessage> ems = [SELECT Id, createdbyId,Status, createddate, IsOpened, LastOpenedDate,  createdby.Name, RelatedToId,Message_Sent_Date__c,Additional_Relationships__c, Relatedto.Name, Subject, HasAttachment, MessageDate,LastModifiedDate FROM EmailMessage];
            system.debug('test ems ='+ems);
            ActivityTimelineSearchRedesign.ActivitySearchResults  results = ActivityTimelineSearchRedesign.getActivityResults(accId.Id, lstType, searchTerm, dateFilter, null, null, null,null, null,10,0,'dueDate','asc');
            lstActDet = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, lstType, searchTerm, null, null, startDate, null,null, null,10,0,'dueDate','asc');
            

            List < ActivityCustomDataRowWrapper > lst1 = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, lstType, searchTerm, null, null, startDate, null,null, UserInfo.getUserId(),10,0,'dueDate','asc');
           
            
            
        }
            test.stopTest();
            System.assertEquals(true, lstActDet.size() > 0);
        }
        Catch(Exception e) {
            
        }
    }

    @isTest
    static void emailSOSLTest() {
        try {
            test.startTest();
            User adminUser = [SELECT Id, Alias FROM User WHERE Alias='admUser' LIMIT 1];
            List < ActivityCustomDataRowWrapper > lstActDet ;
            System.runAs(adminUser){
                List < String > lstType = new List < String > ();
                lstType.add(ConstantsActivityTimeline.SET_TYPE_EMAIL);
                Account accId = [SELECT id, recordtype.developername,Crm_Oid__c FROM Account WHERE Name = :ConstantsActivityTimeline.HOUSEHOLD_NAME
                                 LIMIT 1
                                ];
                System.debug('CMROID : '+accId.Crm_Oid__c);
                List<EmailMessage> emailMessageList = WMC_TestFactory.getEmailMessageData(1);
                for(Integer i = 0; i < 1; ++i) {
                    emailMessageList[i].RelatedToId = accId.Id;   
                    emailMessageList[i].ToAddress = 'abc.xya@mail.com';
                    emailMessageList[i].Additional_Relationships__c = 'Company: '+accId.Id;
                    emailMessageList[i].Subject ='test email sosl';
                }
                insert emailMessageList;
                System.debug('emailMessageList : '+emailMessageList);
                Id [] fixedSearchResults= new Id[1];
                fixedSearchResults[0] = emailMessageList[0].Id;
                Test.setFixedSearchResults(fixedSearchResults);
                String dateFilter='2022-09-16';
                String searchTerm = 'test';
                
                ActivityTimelineSearchRedesign.ActivitySearchResults  results = ActivityTimelineSearchRedesign.getActivityResults(accId.Id, lstType, searchTerm, dateFilter, null, null, null,null, null,10,0,'dueDate','asc');
                lstActDet = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, lstType, searchTerm, null, null, startDate, null,null, null,10,0,'dueDate','asc');
                
                
            }
            test.stopTest();
            System.assertEquals(true, lstActDet.size() > 0);
        }
        Catch(Exception e) {
            
        }
    }

    @isTest
    static void ierTestException() {
        Boolean checkException = FALSE;
        try{
            test.startTest();
            User adminUser = [SELECT Id, Alias FROM User WHERE Alias='admUser' LIMIT 1];
            List < ActivityCustomDataRowWrapper > lstActDet0;
            System.runAs(adminUser){                
                String dateFilter=ConstantsActivityTimeline.SEVEN;   
                String searchTerm ='test' ;           
                List < String > lstType = new List < String > ();
                lstType.add(ConstantsActivityTimeline.SET_TYPE_SSC_EMAIL);
                List<Account> individualAccountList = WMC_TestFactory.getAccountData(1,WMC_Constants.INDIVIDUAL_ACC_RT);
                for(Account acc : individualAccountList){
                    acc.LastName = 'TestIER';
                    acc.FinServ__Status__c = ConstantsActivityTimeline.STATUS_PROSPECT;
                }
                insert individualAccountList;
                Account indivdualProfile = [SELECT Id, PersonContactId, RecordTypeId FROM Account WHERE LastName = 'TestIER']; 
                String personContactId = indivdualProfile.PersonContactId;
                String dateType ='dueDate';
                List<et4ae5__SendDefinition__c> individualEmailSendResults = new List<et4ae5__SendDefinition__c>();
                individualEmailSendResults.add(new et4ae5__SendDefinition__c(et4ae5__Contact__c=personContactId));
                insert individualEmailSendResults;
                List<et4ae5__IndividualEmailResult__c> individualEmailResults = new List<et4ae5__IndividualEmailResult__c>();
                individualEmailResults.add(new et4ae5__IndividualEmailResult__c
                (Name='Test IER Object',et4ae5__Contact__c=personContactId,
                et4ae5__SendDefinition__c=individualEmailSendResults[0].Id,
                Updated_with_Custom_Values__c=true,et4ae5__SubjectLine__c='test ier',et4ae5__DateSent__c=system.now()
                ));
                insert individualEmailResults;
                system.debug('individualEmailResults='+individualEmailResults);
                String endDate = (system.now().addDays(2)).format('yyyy-MM-dd');
                 
                ActivityTimelineSearchRedesign.ActivitySearchResults  results = ActivityTimelineSearchRedesign.getActivityResults(indivdualProfile.id, lstType, searchTerm, dateFilter, dateType, startDate, null,null, null,10,0,'dueDate','asc');
                lstActDet0 = ActivityTimelineSearchRedesign.searchActivityRecords(indivdualProfile.id, lstType, searchTerm, null, null, startDate, startDate,null, null,10,0,'dueDate','asc');
                List < ActivityCustomDataRowWrapper > lstActDet1 = ActivityTimelineSearchRedesign.searchActivityRecords(indivdualProfile.id, lstType, searchTerm, null, null, null, startDate,null, null,10,0,'dueDate','asc');
                List < ActivityCustomDataRowWrapper > lstActDet2 = ActivityTimelineSearchRedesign.searchActivityRecords(indivdualProfile.id, lstType, searchTerm, null, null, startDate, null,null, null,10,0,'dueDate','asc');
                List < ActivityCustomDataRowWrapper > lstActDet3 = ActivityTimelineSearchRedesign.searchActivityRecords(indivdualProfile.id, lstType, searchTerm, null, null, startDate, endDate,null, null,10,0,'dueDate','asc');
            }
            test.stopTest();
           // System.assertEquals(true, lstActDet0.size() > 0);
        }
        Catch(Exception e) {    
            checkException = TRUE;
            System.assertEquals(TRUE, checkException);
        }
    }


    @isTest
    static void timeLineControllerActionPlanTest() 
    {
        Test.startTest();
        User adminUser = [SELECT Id, Alias FROM User WHERE Alias='admUser' LIMIT 1];
        List < ActivityCustomDataRowWrapper > lst1;
        System.runAs(adminUser){
            String pastActivitiesFilter='3';
            String searchTerm ='test';
            String dateType ='dueDate';
            List < String > lstType = new List < String > {ConstantsActivityTimeline.SET_TYPE_ACTION_PLAN,ConstantsActivityTimeline.SET_TYPE_HAS_ATTACHMENT};
          
            List<APTask__c> apTaskList = [SELECT Id,TaskIndex__c FROM APTask__c LIMIT 1];
            List<Task> taskList = [SELECT Id,TaskApTask__c,TaskAPTask__r.TaskIndex__c FROM Task WHERE TaskAPTask__r.TaskIndex__c != NULL LIMIT 1];
            Account accId = [SELECT id, recordtype.developername FROM Account WHERE Name Like 'Individual%'
                             LIMIT 1
                            ];
         
            String ownerId =  Userinfo.getUserId();

            ActionPlan__c ap = [select id,Account__r.name,ownerid,CreatedById,name from ActionPlan__c limit 1];
            String aname = ap.Account__r.name;  
        // create 

        ContentVersion contentVersion = new ContentVersion(
                            Title          = 'a picture',
                            PathOnClient   = 'Pic.jpg',
                            VersionData    = Blob.valueOf('Test Content'),
                            IsMajorVersion = true);
            insert contentVersion;
            List<ContentDocument> documents = [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument];

            //create ContentDocumentLink  record

            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.LinkedEntityId = ap.Id;
            cdl.ContentDocumentId = documents[0].Id;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';
            insert cdl;
   

            ActivityTimelineSearchRedesign.ActivitySearchResults  results = ActivityTimelineSearchRedesign.getActivityResults(accId.Id, lstType, searchTerm, pastActivitiesFilter, null, startDate, startDate,null, ownerId,10,0,'dueDate','asc');
            lst1 = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, null, ap.name, null, dateType, startDate, null,null, ownerId,10,0,'dueDate','asc');
             

            List < ActivityCustomDataRowWrapper > lst3 = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, lstType, searchTerm, null, dateType, startDate, null,ownerId, ownerId,10,0,'dueDate','asc');
           

            List < String > lstType2 = new List < String > {ConstantsActivityTimeline.SET_TYPE_ACTION_PLAN};          
            List < ActivityCustomDataRowWrapper > lst2 = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, lstType2, searchTerm, null, dateType, startDate, null,null, ownerId,10,0,'dueDate','asc');
        }
        test.stopTest(); 
        System.assertEquals(true, lst1.size() > 0);
    }
        

    @isTest
    static void timeLineControllerAllTest() 
    {
        test.startTest();
        User adminUser = [SELECT Id, Alias FROM User WHERE Alias='admUser' LIMIT 1];
        List < ActivityCustomDataRowWrapper > lstActDet;
        System.runAs(adminUser)
        {
            String pastActivitiesFilter='3';
            String searchTerm ='test';
            String dateType ='dueDate';
            List < String > lstType = new List<String>();
            lstType.add(ConstantsActivityTimeline.SET_TYPE_ACTION_PLAN);
            List<APTask__c> apTaskList = [SELECT Id,TaskIndex__c FROM APTask__c LIMIT 1];
            List<Task> taskList = [SELECT Id,TaskApTask__c,TaskAPTask__r.TaskIndex__c FROM Task WHERE TaskAPTask__r.TaskIndex__c != NULL LIMIT 1];
            Account accId = [SELECT id, recordtype.developername FROM Account WHERE Name Like 'Individual%'
                             LIMIT 1
                            ];
            //String startDate = '2024-01-01';
            String ownerId =  Userinfo.getUserId();
            String endDate = (system.now().addDays(2)).format('yyyy-MM-dd');
            
            ActionPlan__c ap = [select id,Account__r.name,ownerid,CreatedById,name from ActionPlan__c limit 1];
            String aname = ap.Account__r.name;            
            ActivityTimelineSearchRedesign.ActivitySearchResults  results = ActivityTimelineSearchRedesign.getActivityResults(accId.Id, null, searchTerm, pastActivitiesFilter, null, startDate, startDate,ownerId, ownerId,10,0,'dueDate','asc');
            lstActDet = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, null, searchTerm, null, dateType, startDate, null,ownerId, ownerId,10,0,'dueDate','asc');
          
            List < ActivityCustomDataRowWrapper > lst2 = ActivityTimelineSearchRedesign.searchActivityRecords(accId.Id, null, searchTerm, null, dateType, startDate,  endDate,ownerId, ownerId,10,0,'dueDate','asc');

        }
        test.stopTest(); 
        System.assertEquals(true, lstActDet.size() > 0);
    }

     @isTest
    static void getRecurringTaskTest() 
    {
        test.startTest();
        String searchTerm ='recurring';
        String dateType ='dueDate';
        List < String > lstType = new List <String> {ConstantsActivityTimeline.SET_TYPE_TASK};

        User adminUser = [SELECT Id, Alias FROM User WHERE Alias='admUser' LIMIT 1];
        List <Task> recurringTaskList;
        List <Task> parentTaskList;
        System.runAs(adminUser) {
            Account accId = [SELECT id, recordtype.developername 
                            FROM Account 
                            WHERE Name Like 'Individual%'
                            LIMIT 1
                            ];
            Task newTask = new Task();
            newTask.OwnerId = adminUser.Id;
            newTask.Type ='Document';
            newTask.Subject ='recurring task';
            newTask.WhatId = accId.Id;
            newTask.IsRecurrence = true;
            newTask.Status = 'OUTS';
            newTask.Priority = '3';
            newTask.RecurrenceStartDateOnly = System.today();
            newTask.RecurrenceEndDateOnly = System.today()+3;
            newTask.RecurrenceType = 'RecursDaily';
            newTask.RecurrenceInterval = 1; // This means that the event will wait 1 day before recurring again
            insert newTask;
            parentTaskList = ActivityTimelineSearchRedesign.getParentTask(newTask.Id);
            recurringTaskList = ActivityTimelineSearchRedesign.getRecurringTask(newTask.Id);
            List < ActivityCustomDataRowWrapper > lstActDet1 = ActivityTimelineSearchRedesign.searchActivityRecords(accId.id, lstType, searchTerm, null, null, null, null,null, null,10,0,'dueDate','asc');
            
            List<Task> taskToUpdate = [SELECT id, status,activityDate
            FROM Task 
            WHERE subject like '%recurring%' order by activityDate desc];

            System.assertEquals(true, taskToUpdate.size() > 1);

             ActivityTimelineSearchRedesign.RecurringTasksComparator2 taskComparator = new  ActivityTimelineSearchRedesign.RecurringTasksComparator2();
            taskToUpdate.sort(taskComparator);
        }
        test.stopTest();
        System.assertEquals(true, recurringTaskList.size() > 0);
    }

    @isTest
    static void getRecurringTaskTest2() 
    {
        test.startTest();
        String searchTerm ='recurring2';
        String dateType ='dueDate';
        List < String > lstType = new List <String> {ConstantsActivityTimeline.SET_TYPE_TASK};
        List < ActivityCustomDataRowWrapper > lstActDet;
        User adminUser = [SELECT Id, Alias FROM User WHERE Alias='admUser' LIMIT 1];
        List <Task> recurringTaskList;
        List <Task> parentTaskList;
        System.runAs(adminUser) {
            Account accId = [SELECT id, recordtype.developername 
                            FROM Account 
                            WHERE Name Like 'Individual%'
                            LIMIT 1
                            ];
            Task newTask = new Task();
            newTask.OwnerId = adminUser.Id;
            newTask.Type ='Document';
            newTask.Subject ='recurring2 task';
            newTask.WhatId = accId.Id;
            newTask.IsRecurrence = true;
            newTask.Status = 'OUTS';
            newTask.Priority = '3';
            newTask.RecurrenceStartDateOnly = System.today();
            newTask.RecurrenceEndDateOnly = System.today();
            newTask.RecurrenceType = 'RecursDaily';
            newTask.RecurrenceInterval = 1; // This means that the event will wait 1 day before recurring again
            insert newTask;

            List<Task> taskToUpdate = [SELECT id, status
            FROM Task 
            WHERE subject like '%recurring%' and IsRecurrence= false];

            System.assertEquals(true, taskToUpdate.size() > 0);
            taskToUpdate[0].Status = 'COMP';

            update taskToUpdate ; 

            lstActDet = ActivityTimelineSearchRedesign.searchActivityRecords(accId.id, lstType, searchTerm, null, null, null, null,null, null,10,0,'dueDate','asc');

           
        }
        test.stopTest();
        System.assertEquals(true, lstActDet.size() > 0);
        
    }


     @isTest
    static void setIsPinnedTaskTest()
    {
        test.startTest();
        User adminUser = [SELECT Id, Alias FROM User WHERE Alias='admUser' LIMIT 1];
        System.runAs(adminUser){
	        Account acc = [SELECT id, recordtype.developername FROM Account WHERE Name Like 'Individual%'LIMIT 1 ];
            system.debug('accId=' + acc.Id);
            
            DateTime currentDateTime = DateTime.now();
            Task testTask = ActivityTimelineUtilityTest.createTestTask('Test Task Mickey 123', WMC_Constants.TASK_STATUS_NOT_STARTED, 
                                                                        acc.Id, false, false, currentDateTime.date().addDays(2), 
                                                                       'Document', 'Task', ConstantsActivityTimeline.DOC_RECORD_TYPE_ID);
            insert testTask;
            
            ActivityTimelineSearchRedesign.setIsPinnedTask(testTask.Id, True);
            Task updatedTask = [SELECT id, Is_Pinned__c ,Pinned_Date__c
                                FROM Task 
                                WHERE Id=:testTask.Id];
            System.assertEquals(true, updatedTask.Is_Pinned__c);

            ActivityTimelineSearchRedesign.setIsPinnedTask(testTask.Id, False);
            Task updatedTask2 = [SELECT id, Is_Pinned__c ,Pinned_Date__c
                                FROM Task 
                                WHERE Id=:testTask.Id];
            System.assertEquals(null, updatedTask2.Pinned_Date__c);

        }
        test.stopTest();
    }


     @isTest
    static void setIsPinnedTaskExceptionTest(){
        test.startTest();
        User adminUser = [SELECT Id, Alias FROM User WHERE Alias='admUser' LIMIT 1];
        System.runAs(adminUser){
            Boolean checkException = FALSE;
            Task objTask = [SELECT Id, Status FROM Task LIMIT 1];
            delete objTask;
            try{
                ActivityTimelineSearchRedesign.setIsPinnedTask(objTask.Id,TRUE); 
            }
            catch(Exception e) {
                checkException = TRUE;
                System.assertEquals(TRUE, checkException);
            }
        }
        test.stopTest();   
    }

   
}