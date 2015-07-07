-module(import_anymeta_tests).

-export([test/1, test_full/1]).

-include_lib("../include/mod_import_anymeta.hrl").


test_full(Context0) ->
    Context = z_acl:sudo(Context0),
    mod_import_anymeta:init(Context),

    Host = "test.com",

    Files = files(),
    FilesWithThingId = lists:zip(lists:seq(1000, 1000+length(Files)-1), Files),

    lists:foldl(
      fun({ThingId, Filename}, Stats) ->
              {ok, Body} = file:read_file(Filename),
              {struct, Thing} = mochijson2:decode(z_string:sanitize_utf8(Body)),
              Stats1 = mod_import_anymeta:import_thing(Host, ThingId, Thing, true, Stats, Context),
              Stats1#stats{
                found=Stats#stats.found+1, 
                consequetive_notfound=0
               }
      end,
      #stats{},
      FilesWithThingId
     ),

    %%Stats = handle_delayed(Stats1#stats.delayed, Host, [], [], true, Stats1#stats{delayed=[]}, Context),
    test(Context).

test(Context0) ->
    Context = z_acl:sudo(Context0),
    Files = files(),

    [FredId, Image1Id, ArticleId, Image2Id, Image3Id, _Keyword1Id, _Keyword2Id, _Keyword3Id, Image4Id, OrgId]
        = lists:map(fun(Seq) -> json_file_to_id(lists:nth(Seq, Files), Context) end, lists:seq(1, length(Files))),

    %% Test artikel
    {trans, T} = m_rsc:p(ArticleId, title, Context),
    <<"Article with images">> = proplists:get_value(en, T),
    <<"Article met plaatjes (nl)">> = proplists:get_value(nl, T),
    %% 3 types
    [_,_,_] = m_edge:objects(ArticleId, has_type, Context),
    %% 3 images
    [Image1Id, Image2Id, Image3Id] = m_edge:objects(ArticleId, depiction, Context),

    %% 'about'
    [OrgId] = m_edge:objects(ArticleId, about, Context),
    
    
    {trans, TB} = m_rsc:p(ArticleId, body, Context),
    <<"<p>Claritas est etiam processus dynamicus, qui sequitur mutationem consuetudium lectorum. Mirum est notare quam littera gothica, quam nunc putamus parum claram, anteposuerit litterarum formas humanitatis per seacula quarta decima et quinta decima. Eodem modo typi, qui nunc nobis videntur parum clari, fiant sollemnes in futurum.</p>">> = proplists:get_value(en, TB),
    <<"">> = proplists:get_value(nl, TB),

    {trans, TI} = m_rsc:p(ArticleId, summary, Context),
    <<"Lorem ipsum dolor sit amet, consectetuer adipiscing">> = proplists:get_value(en, TI),
    <<"Tekst in het nederlands">> = proplists:get_value(nl, TI),

    
    %% Test persoon
    <<"FredP">> = z_trans:trans(m_rsc:p(FredId, title, Context), Context),
    <<"Fred">> = m_rsc:p(FredId, name_first, Context),
    <<"P">> = m_rsc:p(FredId, name_surname, Context),

    %% fred -> likes -> org
    [OrgId] = m_edge:objects(FredId, interest, Context),
    %% fred -> works_for -> org
    [OrgId] = m_edge:objects(FredId, works_for, Context),

    %% test the org
    [Image4Id] = m_edge:objects(OrgId, depiction, Context),
    
    lager:info("All tests ok.").


files() ->
    filelib:wildcard(code:lib_dir(zotonic) ++ "/priv/modules/mod_import_anymeta/testdata/*.json").

json_file_to_id(File, Context) ->
    {ok, Body} = file:read_file(File),
    {struct, Thing} = mochijson2:decode(z_string:sanitize_utf8(Body)),
    RscUri = proplists:get_value(<<"resource_uri">>, Thing),
    {ok, Id} = mod_import_anymeta:find_any_id(RscUri, Context),
    Id.


