%%--------------------------------------------------------------------
%% Copyright (c) 2019 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(emqx_auth_mysql_cli).

-behaviour(ecpool_worker).

-include("emqx_auth_mysql.hrl").
-include_lib("emqx/include/emqx.hrl").

-export([ parse_query/1
        , connect/1
        , query/3
        ]).

%%--------------------------------------------------------------------
%% Avoid SQL Injection: Parse SQL to Parameter Query.
%%--------------------------------------------------------------------

parse_query(undefined) ->
    undefined;
parse_query(Sql) ->
    case re:run(Sql, "'%[ucCad]'", [global, {capture, all, list}]) of
        {match, Variables} ->
            Params = [Var || [Var] <- Variables],
            {re:replace(Sql, "'%[ucCad]'", "?", [global, {return, list}]), Params};
        nomatch ->
            {Sql, []}
    end.

%%--------------------------------------------------------------------
%% MySQL Connect/Query
%%--------------------------------------------------------------------

connect(Options) ->
    mysql:start_link(Options).

query(Sql, Params, ClientInfo) ->
    ecpool:with_client(?APP, fun(C) -> mysql:query(C, Sql, replvar(Params, ClientInfo)) end).

replvar(Params, ClientInfo) ->
    replvar(Params, ClientInfo, []).

replvar([], _ClientInfo, Acc) ->
    lists:reverse(Acc);
replvar(["'%u'" | Params], ClientInfo = #{username := Username}, Acc) ->
    replvar(Params, ClientInfo, [Username | Acc]);
replvar(["'%c'" | Params], ClientInfo = #{clientid := ClientId}, Acc) ->
    replvar(Params, ClientInfo, [ClientId | Acc]);
replvar(["'%a'" | Params], ClientInfo = #{peerhost := PeerHost}, Acc) ->
    replvar(Params, ClientInfo, [inet_parse:ntoa(PeerHost) | Acc]);
replvar(["'%C'" | Params], ClientInfo = #{cn := CN}, Acc) ->
    replvar(Params, ClientInfo, [CN | Acc]);
replvar(["'%d'" | Params], ClientInfo = #{dn := DN}, Acc) ->
    replvar(Params, ClientInfo, [DN | Acc]);
replvar([Param | Params], ClientInfo, Acc) ->
    replvar(Params, ClientInfo, [Param | Acc]).

