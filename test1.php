<?php
@dl("vuehelper.so");

$css = '.test bla tr td.a {
  font-size: 1.1em;
  color: green;
}
td.t_est {
  color: red; }
#scroll { overflow: scroll }
td.h, th.h { color: blue }
';

$test2 = file_get_contents('pdwe-marktfilter.vue');

$id = "_v12";

#echo scoped_css($css, $id).PHP_EOL;
var_dump(process_vue($test2));
