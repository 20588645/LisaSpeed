/// Shared “homepage probe ≠ usable site” grading for the test page and line check.
enum ProbeGrade { ok, sluggish, switchNode }

const kProbeSluggishMs = 400;
const kProbeSwitchNodeMs = 1000;

ProbeGrade gradeLatencyMs(int ms) {
  if (ms < kProbeSluggishMs) return ProbeGrade.ok;
  if (ms < kProbeSwitchNodeMs) return ProbeGrade.sluggish;
  return ProbeGrade.switchNode;
}
