module PhlatScript
  require_relative 'TestBase'
  require_relative '../../Phlatboyz/utils/IniParser'

  class IniParserTest < TestBase

    def run()
      parser = IniParser.new()
      sections = parser.parseFileAtPath(File.join(File.dirname(__FILE__), '../data/sample.ini'))
      assertTrue(parser.isSectionLine("[xx]"),"this should be a section line");
      assertFalse(parser.isSectionLine("xx]"),"this should not be a section line");
      assertTrue(parser.isPropertyLine("ss=ss"),"this should be a property line");
      assertFalse(parser.isPropertyLine(";==="),"this should not be a property line");
      assertTrue(sections.length() == 2, "there should be 2 sections")
      assertEquals(parser.removeCommentFromLine("aa=bb;comment"),"aa=bb","comment at the end of line was not removed properly")
      assertNotNull(sections["section1"], "section1 missing")
      assertNotNull(sections["section2"], "section2 missing")
      assertEquals(sections["section1"]['attr1'],"1","wrong value")
      assertEquals(sections["section1"]['attr2'],"2","wrong value")
      assertEquals(sections["section1"]['attr3'],"3","wrong value")
      assertEquals(sections["section2"]['attr1'],"1","wrong value")
      assertEquals(sections["section2"]['attr2'],"2","wrong value")
      assertEquals(sections["section2"]['attr3'],"3","wrong value")
      assertException("should catch exception for incorrect file") {
        parser.parseFileAtPath(File.join(File.dirname(__FILE__), '../data/wrong-sample.ini'))
      }
    end
  end
end
