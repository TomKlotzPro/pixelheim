"""No new reach into another script's _func (PIX-361): the count
`codegraph.py --private` prints only goes down. A raw `X._data()` read from
another script is one; ask the owning class a named question instead.

    python3 -m unittest discover -s godot/tools -p 'test_*.py'
"""
import unittest

import codegraph

# The count once Bestiary, Npcs, Economy and Town answered by name (PIX-361
# part 17, from 163). Lower it when you take one apart; never raise it.
CEILING = 63


class PrivateCallsTest(unittest.TestCase):
    def test_no_new_reach_into_a_private_func(self):
        graph = codegraph.build(codegraph.REPO)
        self.assertLessEqual(graph.private_count(), CEILING,
                             "a call reaches into another script's _func; the ones there are:\n"
                             + "\n".join(graph.private_calls()))


if __name__ == "__main__":
    unittest.main()
