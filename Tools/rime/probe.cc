// Loads Rime exactly like the keyboard extension (prebuilt data, no maintenance) and prints
// the top candidates for each argument, plus the process memory footprint.
//   c++ -std=c++17 -I<headers> probe.cc libRime.a -o probe && ./probe <RimeData> <user_dir> nzzsm nh ...
#include <cstdio>
#include <cstring>
#include <string>
#include <mach/mach.h>
#include "rime_api.h"

static double footprintMB() {
  task_vm_info_data_t info; mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
  task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count);
  return info.phys_footprint / 1048576.0;
}

int main(int argc, char** argv) {
  if (argc < 4) { fprintf(stderr, "usage: probe <shared> <user> input...\n"); return 2; }
  std::string shared = argv[1], user = argv[2];
  std::string prebuilt = shared + "/build", staging = user + "/build";
  RimeApi* rime = rime_get_api();
  RIME_STRUCT(RimeTraits, traits);
  traits.shared_data_dir = shared.c_str();
  traits.user_data_dir = user.c_str();
  traits.prebuilt_data_dir = prebuilt.c_str();
  traits.staging_dir = staging.c_str();
  traits.distribution_name = "PlanetKeyboard";
  traits.distribution_code_name = "planet";
  traits.distribution_version = "1.0";
  traits.app_name = "rime.planet";
  traits.min_log_level = 3;
  rime->setup(&traits);
  rime->initialize(&traits);
  printf("init footprint %.1f MB\n", footprintMB());
  RimeSessionId s = rime->create_session();
  if (!rime->select_schema(s, "planet_pinyin")) { printf("select_schema failed\n"); }
  for (int i = 3; i < argc; i++) {
    rime->clear_composition(s);
    for (const char* p = argv[i]; *p; p++) rime->process_key(s, *p, 0);
    RIME_STRUCT(RimeContext, ctx);
    if (rime->get_context(s, &ctx)) {
      printf("%-18s preedit=[%s] ", argv[i], ctx.composition.preedit ? ctx.composition.preedit : "");
      RimeCandidateListIterator it = {0};
      int n = 0;
      if (rime->candidate_list_begin(s, &it)) {
        while (rime->candidate_list_next(&it) && n < 8) { printf("%s ", it.candidate.text); n++; }
        rime->candidate_list_end(&it);
      }
      printf("\n");
      rime->free_context(&ctx);
    }
  }
  printf("after lookups footprint %.1f MB\n", footprintMB());
  rime->destroy_session(s);
  rime->finalize();
  return 0;
}
