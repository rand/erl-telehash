% handles encoding/decoding and manipulating telexes

-module(th_telex).

-include("conf.hrl").

-export([encode/1, decode/1, get/2, set/3, update/4, end_signal/1, see_command/1, key_type/1]).

% --- api ---

encode(Telex) ->
    Json =
	try
	    iolist_to_binary(mochijson2:encode(Telex))
	catch 
	    _:Error ->
		erlang:error({telex, encode, Error, Telex})
	end,
    case byte_size(Json) =< ?TELEX_MAX_BYTES of
	true -> Json;
	false -> erlang:error({telex, encode, too_big, Telex})
    end.

decode(Json) ->
    case byte_size(Json) =< ?TELEX_MAX_BYTES of
	true -> ok;
	false -> erlang:error({telex, decode, too_big, Json})
    end,
    try
	mochijson2:decode(Json)
    catch 
	_:Error ->
	    erlang:error({telex, decode, Error, Json})
    end.

get(Telex, Key) when is_list(Key) ->
    get(Telex, list_to_binary(Key));
get(Telex, Key) when is_atom(Key) ->
    get(Telex, list_to_binary(atom_to_list(Key)));
get({struct, Telex}, Key) when is_list(Telex) and is_binary(Key) ->
    case lists:keyfind(Key, 1, Telex) of
	false -> {error, not_found};
	{Key, Value} -> {ok, Value}
    end;
get(Telex, Index) when is_list(Telex) and is_integer(Index) ->
    case Index =< length(Telex) of
	false -> {error, not_found};
	true -> {ok, lists:nth(Index, Telex)}
    end;
get(Telex, Path) when is_tuple(Path) ->
    get_path(Telex, tuple_to_list(Path));
get(_Telex, _Key) ->
    % !!! not too happy about obscuring badarg
    {error, not_found}.

get_path(Telex, []) ->
    Telex;
get_path(Telex, [Path_elem | Path]) ->
    case get(Telex, Path_elem) of
	{error, not_found} -> {error, not_found};
	{ok, Telex2} -> get_path(Telex2, Path)
    end.

set(Telex, Key, Value) ->
    update(Telex, Key, fun (_T) -> Value end, Value).

% !!! check new value is valid json
update(Telex, Key, F, Default) when is_list(Key) ->
    update(Telex, list_to_binary(Key), F, Default);
update(Telex, Key, F, Default) when is_atom(Key) ->
    update(Telex, list_to_binary(atom_to_list(Key)), F, Default);
update({struct, Telex}, Key, F, Default) when is_list(Telex) and is_binary(Key) ->
    case lists:keyfind(Key, 1, Telex) of
	{Key, Value} -> {struct, lists:keyreplace(Key, 1, Telex, {Key, F(Value)})};
	false -> {struct, [{Key, Default} | Telex]}
    end;
update(Telex, Index, F, _Default) when is_list(Telex) and is_integer(Index) ->
    % !!! behaviour for out of range indexes?
    th_util:set_nth(Index, Telex, F(lists:nth(Index, Telex)));
update(Telex, Path, F, Default) when is_tuple(Path) ->
    update_path(Telex, tuple_to_list(Path), F, Default).

update_path(Telex, [], F, _Default) ->
    F(Telex);
update_path(Telex, [Path_elem | Path], F, Default) ->
    update(Telex, Path_elem, fun (T) -> update_path(T, Path, F, Default) end, Default).

end_signal({'end', _}=End) ->
    {struct, [{'+end', th_util:end_to_hex(End)}]}.

see_command(Addresses) ->
    {struct, [{'.see', [th_util:address_to_binary(Address) || Address <- Addresses]}]}.

%tap_command(Tap) ->
%    {struct, [{'.tap', tap_to_json(Tap)}]}.

key_type(Key) when is_binary(Key) ->
    case Key of
	<< "_", _/binary >> ->
	    header;
	<< "+", _/binary >> ->
	    signal;
	<< ".", _/binary >> ->
	    command;
	_ ->
	    normal
    end.

% --- internal functions ---

%tap_to_json(Tap) ->
%    map(Tap,
%	fun (Rule) ->
%		{struct, 

map(List, Fun) -> lists:map(Fun, List).

% --- end ---
