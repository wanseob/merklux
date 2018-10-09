const hexToString = hex => {
  const hexCodes = hex.startsWith('0x') ? hex.substr(2) : hex
  let str = ''
  let i
  for (i = 0; (i < hexCodes.length && hexCodes.substr(i, 2) !== '00'); i += 2) {
    str += String.fromCharCode(parseInt(hexCodes.substr(i, 2), 16))
  }
  return str
}

const toNodeObject = (depth, label, node) => {
  return {
    parent: label,
    depth,
    labelLength: node[0].toNumber(),
    labelData: node[1],
    node: node[2]
  }
}

const progress = {
  log: async (output, ms) => {
    process.stdout.clearLine()
    process.stdout.cursorTo(0)
    process.stdout.write(`Progress >>\t${output}`)
    if (ms) {
      let sleep = () => new Promise(resolve => setTimeout(resolve, ms))
      await sleep()
    }
  },
  close: () => {
    process.stdout.clearLine()
    process.stdout.cursorTo(0)
    process.stdout.write('')
  }
}

module.exports = {
  hexToString,
  toNodeObject,
  progress
}
