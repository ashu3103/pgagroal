/*
 * Copyright (C) 2025 The pgagroal community
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this list
 * of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice, this
 * list of conditions and the following disclaimer in the documentation and/or other
 * materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its contributors may
 * be used to endorse or promote products derived from this software without specific
 * prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
 * OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
 * TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <tsclient.h>

#include "pgagroal_test_2.h"

// baseline
START_TEST(test_pgagroal_baseline)
{
    int found = 0;
    found = !pgagroal_tsclient_execute_pgbench("postgres", true, 10, 0, 1000);
    ck_assert_msg(found, "success status not found");
}

// high_clients
START_TEST(test_pgagroal_high_clients)
{
    int found = 0;
    found = !pgagroal_tsclient_execute_pgbench("postgres", true, 50, 0, 1000);
    ck_assert_msg(found, "success status not found");
}

// high_transactions
START_TEST(test_pgagroal_high_transactions)
{
    int found = 0;
    found = !pgagroal_tsclient_execute_pgbench("postgres", true, 10, 0, 5000);
    ck_assert_msg(found, "success status not found");
}

// combined
START_TEST(test_pgagroal_combined)
{
    int found = 0;
    found = !pgagroal_tsclient_execute_pgbench("postgres", true, 50, 0, 5000);
    ck_assert_msg(found, "success status not found");
}

Suite*
pgagroal_test2_suite()
{
Suite* s;
TCase* tc_core;

s = suite_create("pgagroal_test2");

tc_core = tcase_create("Core");

tcase_set_timeout(tc_core, 60);
tcase_add_test(tc_core, test_pgagroal_baseline);
suite_add_tcase(s, tc_core);

return s;
}