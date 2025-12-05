@IsTest
private class AccountServiceTest {

    @IsTest
    static void testCreateAccount_success() {
        Test.startTest();

        Account acc = AccountService.createAccount('Test Account', '123-456-7890');

        Test.stopTest();

        System.assertNotEquals(null, acc, 'Method should return an Account');
        System.assertNotEquals(null, acc.Id, 'Account should be inserted and have an Id');

        Account accFromDb = [
            SELECT Id, Name, Phone
            FROM Account
            WHERE Id = :acc.Id
        ];
        System.assertEquals('Test Account', accFromDb.Name, 'Name should match input');
        System.assertEquals('123-456-7890', accFromDb.Phone, 'Phone should match input');
    }

    @IsTest
    static void testCreateAccount_blankName_returnsNull() {
        Test.startTest();

        Account acc = AccountService.createAccount('', '111-222-3333');

        Test.stopTest();

        System.assertEquals(null, acc, 'Blank name should return null and not insert');
        // Extra safety: make sure nothing sneaked into the DB
        Integer count = [
            SELECT COUNT()
            FROM Account
            WHERE Phone = '111-222-3333'
        ];
        System.assertEquals(0, count, 'No account should be inserted for blank name');
    }

    @IsTest
    static void testCountAccountsByPhone() {
        // Arrange: create some test Accounts
        List<Account> accs = new List<Account>{
            new Account(Name = 'A1', Phone = '999-999-9999'),
            new Account(Name = 'A2', Phone = '999-999-9999'),
            new Account(Name = 'A3', Phone = '111-111-1111')
        };
        insert accs;

        Test.startTest();

        Integer count = AccountService.countAccountsByPhone('999-999-9999');

        Test.stopTest();

        System.assertEquals(2, count, 'Should count only Accounts with the matching phone');
    }
}