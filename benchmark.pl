use HTTPD::Bench::ApacheBench;

         my $b = HTTPD::Bench::ApacheBench->new;

         # global configuration
         $b->concurrency(5);
         $b->priority("run_priority");

         # add HTTP request sequences (aka: runs)
         my $run1 = HTTPD::Bench::ApacheBench::Run->new
           ({ urls => ["http://localhost/one", "http://localhost/two"] });
         $b->add_run($run1);

         my $run2 = HTTPD::Bench::ApacheBench::Run->new
           ({ urls    => ["http://localhost/three",
"http://localhost/four"],
              cookies => ["Login_Cookie=b3dcc9bac34b7e60;"],
              order   => "depth_first",
              repeat  => 10,
              memory  => 2 });
         $b->add_run($run2);

         # send HTTP request sequences to server and time responses
         my $ro = $b->execute;

         # calculate hits/sec
         print (1000*$b->total_requests/$b->total_time)." req/sec\n";

         # show request times (in ms) for $run1, 1st repetition
         print join(', ', @{$run1->request_times}) . "\n";

         # show response times (in ms) for $run2, 7th repetition
         print join(', ', @{$run2->iteration(6)->response_times}) . "\n";

         # dump the entire regression object (WARNING, this could be a LOT
OF DATA)
         use Data::Dumper;
         my $d = Data::Dumper->new([$ro]);
         print $d->Dumpxs;

