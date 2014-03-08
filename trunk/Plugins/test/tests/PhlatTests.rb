module PhlatScript

  require_relative "IniParserTest"
  require_relative "IniGeneratorTest"

  class TestSuite

    def runTests()
      # add your test classes here...
      # every class needs to have run method implemented.
      allTests = [IniParserTest.new(), IniGeneratorTest.new()]

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