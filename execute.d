module execute;

import std.string;

public string exec(string arg) {
	return ("The answer is 42 and not " ~ arg).strip;
}
