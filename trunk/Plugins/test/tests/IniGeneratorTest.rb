module PhlatScript
  require_relative 'TestBase'
  require_relative '../../Phlatboyz/utils/IniParser'
  class IniGeneratorTest < TestBase
    def run()
      generator = IniGenerator.new()

      assertException("should raise exception for incorrect parameter") {
        generator.hashMapToIni("ss");
      }
      assertException("should raise exception for incorrect parameter") {
        generator.hashMapToIni({"ss"=>"xx"});
      }
      
      assertTrue(generator.isSimpleType("a"),"should be a simple type")
      assertTrue(generator.isSimpleType(1),"should be a simple type")
      assertTrue(generator.isSimpleType(1.0),"should be a simple type")
      assertFalse(generator.isSimpleType(["d", "d"]),"should be a complex type")
      assertFalse(generator.isSimpleType({"d"=>"d"}),"should be a complex type")
      map = {"section"=>{"a"=>"b"}}
      result = generator.hashMapToIni({"section"=>{"a"=>"b"}});
      assertEquals(result,"[section]\na=b\n","should be equal")
      generator.dumpHashMapToIni(map,"map.ini")
      assertTrue((File.exist?"__test_file_map.ini"), "file needs to exist after dump");
      File.delete("__test_file_map.ini")
    end
  end
end
