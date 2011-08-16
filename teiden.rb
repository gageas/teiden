require 'net/http'
require 'rexml/document'

class Teiden
	@@APIDomain = "mukku.org"
	@@APIPath = "/v2.00/TGL/"

	def initialize(timeGroup, minutesToHalt = 5, minutesToWake = 5)
		@timeGroup = timeGroup[0..0]
		@subGroup = timeGroup[1..1]
		@secToHalt = minutesToHalt * 60
		@secToWake = minutesToWake * 60
	end

	def fetch
		begin
			xml = Net::HTTP.get(@@APIDomain, @@APIPath)
			return xml
		rescue
			p $!
			return nil
		end
	end

	def exec
		xml = self.fetch
		return if xml.nil?

		doc = createAndCheck(xml)
		return if doc.nil?

		entry = REXML::XPath.first(doc, "//Result/TimeGroup/Group[self::node()='#{@timeGroup}']/../SubGroup[self::node()='#{@subGroup}']/../")
		unless entry.nil? then
			cutOffCount = REXML::XPath.first(doc, "//Count/text()").to_s.to_i
			timeStart = REXML::XPath.first(doc, "//Start/text()").to_s.to_i
			timeEnd = REXML::XPath.first(doc, "//End/text()").to_s.to_i

			if cutOffCount == 0 then puts "power cutoff is NOT scheduled."; return end
			if timeEnd < Time.new.to_i then return end
			if timeStart < Time.new.to_i + @secToHalt then
				`logger "Power cutoff is scheduled #{Time.at timeStart} to #{Time.at timeEnd}. Going to halt now!!!"`
				`echo #{timeEnd + @secToWake} > /sys/class/rtc/rtc0/wakealarm`
				`shutdown -h now`
			end
		end
	end

	def createAndCheck(xml)
		success = false
		begin
			doc = REXML::Document.new(xml)
			unless doc.nil? then
				doc.elements.each("//TeidenAPI/ResultInfo/Status"){|e|
					success = true if e.text == "OK"
				}
			end
		rescue
		end
		if success then doc else nil end
	end
end

# 以下を適宜書き換える
teiden = Teiden.new("1E")
teiden.exec()
