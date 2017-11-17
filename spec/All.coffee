noflo = require 'noflo'

unless noflo.isBrowser()
  chai = require 'chai'
  path = require 'path'
  baseDir = path.resolve __dirname, '../'
else
  baseDir = 'noflo-flow'

describe 'All component', ->
  c = null
  ins = []
  errIn = null
  out = null
  errOut = null

  before (done) ->
    @timeout 4000
    loader = new noflo.ComponentLoader baseDir
    loader.load 'flow/All', (err, instance) ->
      return done err if err
      c = instance
      ins.push noflo.internalSocket.createSocket()
      ins.push noflo.internalSocket.createSocket()
      ins.push noflo.internalSocket.createSocket()
      ins.push noflo.internalSocket.createSocket()
      ins.push noflo.internalSocket.createSocket()
      errIn = noflo.internalSocket.createSocket()
      instance.inPorts.error.attach errIn
      done()
  beforeEach ->
    out = noflo.internalSocket.createSocket()
    c.outPorts.out.attach out
    errOut = noflo.internalSocket.createSocket()
    c.outPorts.error.attach errOut
  afterEach ->
    c.outPorts.out.detach out
    out = null
    c.outPorts.error.detach errOut
    errOut = null
  describe 'receiving results for two inbound connections', ->
    before ->
      c.inPorts.in.attach ins[0]
      c.inPorts.in.attach ins[1]
    after (done) ->
      c.inPorts.in.detach ins[1]
      c.inPorts.in.detach ins[0]
      c.shutdown done
    it 'should send the results out', (done) ->
      errOut.on 'data', done
      out.on 'data', (data) ->
        chai.expect(data).to.eql [
          ['hello world']
          [123]
        ]
        done()
      ins[1].send 123
      ins[0].send 'hello world'
    it 'should support a stream in input data', (done) ->
      errOut.on 'data', done
      out.on 'data', (data) ->
        chai.expect(data).to.eql [
          ['hello world']
          [123, 456]
        ]
        done()
      ins[1].send new noflo.IP 'openBracket', null,
        scope: 0
      ins[1].send new noflo.IP 'data', 123,
        scope: 0
      ins[1].send new noflo.IP 'data', 456,
        scope: 0
      ins[1].send new noflo.IP 'closeBracket', null,
        scope: 0
      ins[0].send new noflo.IP 'data', 'hello world',
        scope: 0
    it 'should only use first stream from input data', (done) ->
      errOut.on 'data', done
      out.on 'data', (data) ->
        chai.expect(data).to.eql [
          ['hello world']
          [123]
        ]
        done()
      ins[1].send new noflo.IP 'data', 123,
        scope: 3
      ins[1].send new noflo.IP 'data', 456,
        scope: 3
      ins[0].send new noflo.IP 'data', 'hello world',
        scope: 3
    it 'should send results by scope', (done) ->
      expected = [
        scope: 2
        data: [['hello world'], [123]]
      ,
        scope: 1
        data: [[5542], ['foo bar']]
      ]
      errOut.on 'data', done
      out.on 'ip', (ip) ->
        return unless ip.type is 'data'
        expect = expected.shift()
        chai.expect(ip.scope).to.equal expect.scope
        chai.expect(ip.data).to.eql expect.data
        return if expected.length
        done()
      ins[0].send new noflo.IP 'data', 5542,
        scope: 1
      ins[1].send new noflo.IP 'data', 123,
        scope: 2
      ins[0].send new noflo.IP 'data', 'hello world',
        scope: 2
      ins[1].send new noflo.IP 'data', 'foo bar',
        scope: 1
  describe 'receiving result and error for two inbound connections', ->
    before ->
      c.inPorts.in.attach ins[0]
      c.inPorts.in.attach ins[1]
    after (done) ->
      c.inPorts.in.detach ins[1]
      c.inPorts.in.detach ins[0]
      c.shutdown done
    it 'should send the error out and no results', (done) ->
      errOut.on 'data', (err) ->
        chai.expect(err).to.be.an 'error'
        chai.expect(err.message).to.equal 'Error on first'
        done()
      out.on 'data', (data) ->
        done new Error 'Unexpected data received'
      ins[1].send 123
      errIn.send new Error "Error on first"
    it 'should send the error out and no results', (done) ->
      errOut.on 'ip', (ip) ->
        return unless ip.type is 'data'
        chai.expect(ip.data).to.be.an 'error'
        chai.expect(ip.data.message).to.equal 'Error on scope'
        chai.expect(ip.scope).to.equal 0
        done()
      out.on 'data', (data) ->
        done new Error 'Unexpected data received'
      ins[1].send new noflo.IP 'data', 123,
        scope: 0
      ins[1].send new noflo.IP 'data', 456,
        scope: 0
      errIn.send new noflo.IP 'data', new Error('Error on scope'),
        scope: 0
    it 'should send results by scope', (done) ->
      expected = [
        scope: 2
        error: 'Second scope failed'
      ,
        scope: 1
        data: [[65432], ['foo bar baz']]
      ]
      errOut.on 'ip', (ip) ->
        return unless ip.type is 'data'
        expect = expected.shift()
        chai.expect(ip.scope).to.equal expect.scope
        chai.expect(ip.data).to.be.an 'error'
        chai.expect(ip.data.message).to.eql expect.error
        return if expected.length
        done()
      out.on 'ip', (ip) ->
        return unless ip.type is 'data'
        expect = expected.shift()
        chai.expect(ip.scope).to.equal expect.scope
        chai.expect(ip.data).to.eql expect.data
        return if expected.length
        done()
      ins[0].send new noflo.IP 'data', 65432,
        scope: 1
      ins[1].send new noflo.IP 'data', 123,
        scope: 2
      errIn.send new noflo.IP 'data', new Error('Second scope failed'),
        scope: 2
      ins[1].send new noflo.IP 'data', 'foo bar baz',
        scope: 1
