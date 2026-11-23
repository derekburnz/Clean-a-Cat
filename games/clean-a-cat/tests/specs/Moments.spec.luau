--!strict
return function()
	local Moments = require(game:GetService("ReplicatedStorage").Shared.Moments)

	describe("Moments", function()
		it("has a signal for every listed name and no unlisted ones", function()
			local count = 0
			for key, value in Moments :: any do
				if key ~= "NAMES" then
					count += 1
					expect(table.find(Moments.NAMES, key) ~= nil).to.equal(true)
					expect(type(value.Connect)).to.equal("function")
					expect(type(value.Fire)).to.equal("function")
				end
			end
			expect(count).to.equal(#Moments.NAMES)
		end)

		it("cannot be replaced or extended at run time", function()
			expect(function()
				(Moments :: any).CatClean = nil
			end).to.throw()
			expect(function()
				table.insert(Moments.NAMES :: any, "Extra")
			end).to.throw()
		end)

		it("delivers the payload to listeners", function()
			local cat = {} :: any
			local gotCat, gotIndex
			local connection = Moments.BrushSwipe:Connect(function(c, index)
				gotCat, gotIndex = c, index
			end)
			Moments.BrushSwipe:Fire(cat, 2)
			connection:Disconnect()
			expect(gotCat).to.equal(cat)
			expect(gotIndex).to.equal(2)
		end)

		it("keeps other listeners running when one errors", function()
			local cat = {} :: any
			local reached = false
			local bad = Moments.CatClean:Connect(function()
				error("broken effect")
			end)
			local good = Moments.CatClean:Connect(function()
				reached = true
			end)
			Moments.CatClean:Fire(cat)
			bad:Disconnect()
			good:Disconnect()
			expect(reached).to.equal(true)
		end)
	end)
end
