#!/bin/bash


# Test script should be run in the base directory
cd `dirname "$0"` && cd ../

if [ -f "truffle.js" ]
then
  echo "Start testing"
else
  echo "You should run this script in the base directory of this project"
  exit 1
fi

# Exit when the test directory is empty
if !([ "$(ls -A ./test/sequence)" ]); then
  echo "There does not exist any test case"
  exit 1
fi

# Terminate running ganaches for testing
kill_ganaches() {
  echo "Terminate ganaches"
  if !([ -z ${rootpid+x} ]);then
    kill $rootpid
  fi

  if !([ -z ${sidepid+x} ]);then
    kill $sidepid
  fi
}

# Compile contracts
truffle compile --all
if !([ $? -eq 0 ]) exit $?


# Run root chain for testing
ganache-cli --port 8547 --networkId 180905 --blocktime 1 > /dev/null & rootpid=$!
if ps -p $rootpid > /dev/null
then
  echo "Running Root Chain..."
else
  echo "Failed to run root chain on 8547 port."
  exit 1
fi

# Run side chain for testing
ganache-cli --port 8548 --networkId 180906 --blocktime 1 > /dev/null & sidepid=$!
if ps -p $sidepid > /dev/null
then
  echo "Running Side Chain..."
else
  echo "Failed to run side chain on 8548 port."
  kill_ganaches
  exit 1
fi

# Deploy contracts on the root chain for testing
truffle migrate --network testRoot
[ $? -ne 0 ] && exit $?

# Deploy contracts on the side chain for testing
truffle migrate --network testSide
[ $? -ne 0 ] && exit $?

sleep 5

# Trap interrupts

# Run test files by orders.
# A test file should have name like {order}-{sort of chain}-{title}.{ext}
# eg. "1-root-firstcase.js", "2-side-secondcase.js"
for testfile in ./test/sequence/*; do
  if [[ "$testfile" =~ ^\.\/test\/[0-9]*-root-.*$ ]]; then
    truffle test $testfile --network testRoot
    [ $? -ne 0 ] && exit $?
  elif [[ "$testfile" =~ ^\.\/test\/[0-9]*-side-.*$ ]]; then
    truffle test $testfile --network testSide
    [ $? -ne 0 ] && exit $?
  else
    echo "Invalid filename: $testfile"
    echo "A test script's file name should be like {order}-{sort of chain}-{title}.{ext}"
    kill_ganaches
    exit 1
  fi
done

kill_ganaches
exit 0
