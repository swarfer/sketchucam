module PhlatScript
  class TestBase
    @@assertionErrorCount = 0
    def setup()
    end

    def run()
    end

    def tearDown()
    end

    def assertTrue(assertBool, message)
      if not assertBool
        @@assertionErrorCount = @@assertionErrorCount + 1
        puts "Assertion error: " + message
      end
    end

    def assertFalse(assertBool, message)
      self.assertTrue((not assertBool),message)
    end

    def assertNotNull(assertObject, message)
      self.assertTrue(assertObject != nil, message)
    end

    def assertNull(assertObject, message)
      self.assertTrue(assertObject == nil, message)
    end

    def assertEquals(val1, val2, message)
      if(val1 != val2)
        @@assertionErrorCount = @@assertionErrorCount + 1
        puts "Assertion error: " + message, ' - expected: ' + val1.to_s + ' got:' + val2.to_s
      end
    end

    def assertException(message, &block)
      begin
        block.call()
      rescue
        return
      end
      puts "No exception caught: " + message
      @@assertionErrorCount = @@assertionErrorCount + 1
    end

    
    def assertionErrorCount
      @@assertionErrorCount
    end
  end
end