local lu = require 'lib/luaunit'

TestFirst = {}

function TestFirst:testSeparateTest()
    lu.assertEquals(false, true)
end