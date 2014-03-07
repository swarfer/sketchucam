module PhlatScript
  
  require_relative "IniParserTest"
  class TestSuite
    def runTests()
      allTests = [IniParserTest.new()]
      allTests.each{ |test|
        test.setup()
        test.run()
        test.tearDown()
        errorStr = (test.assertionErrorCount ==1)? " error" : " errors" 
        puts 'finished test: ' +test.class.name + ' with ' + test.assertionErrorCount.to_s + errorStr
      }
    end
  end
  testSuite = TestSuite.new()
  testSuite.runTests()
end