port module Main exposing (Model, Msg(..), init, main, update, view)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Json.Decode
import Json.Decode.Pipeline
import Json.Encode


port signIn : () -> Cmd msg


port signInInfo : (Json.Encode.Value -> msg) -> Sub msg


port signInError : (Json.Encode.Value -> msg) -> Sub msg


port signOut : () -> Cmd msg


port saveMessage : Json.Encode.Value -> Cmd msg


port receiveMessages : (Json.Encode.Value -> msg) -> Sub msg



---- MODEL ----


type alias MessageContent =
    { content : String, time : String, date : String}


type alias ErrorData =
    { code : Maybe String, message : Maybe String, credential : Maybe String }


type alias UserData =
    { token : String, email : String, uid : String }


type alias Model =
    { userData : Maybe UserData, error : ErrorData, inputContent : String, inputDate : String, inputTime : String, messages : List MessageContent}


init : ( Model, Cmd Msg )
init =
    ( { userData = Maybe.Nothing, error = emptyError, inputContent = "", inputDate = "", inputTime = "", messages = [] }, Cmd.none )



---- UPDATE ----


type Msg
    = LogIn
    | LogOut
    | LoggedInData (Result Json.Decode.Error UserData)
    | LoggedInError (Result Json.Decode.Error ErrorData)
    | SaveMessage
    | InputChanged String
    | DateChanged String
    | TimeChanged String
    | MessagesReceived (Result Json.Decode.Error (List MessageContent))


emptyError : ErrorData
emptyError =
    { code = Maybe.Nothing, credential = Maybe.Nothing, message = Maybe.Nothing }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LogIn ->
            ( model, signIn () )

        LogOut ->
            ( { model | userData = Maybe.Nothing, error = emptyError }, signOut () )

        LoggedInData result ->
            case result of
                Ok value ->
                    ( { model | userData = Just value }, Cmd.none )

                Err error ->
                    ( { model | error = messageToError <| Json.Decode.errorToString error }, Cmd.none )

        LoggedInError result ->
            case result of
                Ok value ->
                    ( { model | error = value }, Cmd.none )

                Err error ->
                    ( { model | error = messageToError <| Json.Decode.errorToString error }, Cmd.none )

        SaveMessage ->
            ( model, saveMessage <| messageEncoder model )

        InputChanged value ->
            ( { model | inputContent = value }, Cmd.none )

        DateChanged value ->
            ( { model | inputDate = value }, Cmd.none )

        TimeChanged value ->
            ( { model | inputTime = value }, Cmd.none )

        MessagesReceived result ->
            case result of
                Ok value ->
                    ( { model | messages = value }, Cmd.none )

                Err error ->
                    ( { model | error = messageToError <| Json.Decode.errorToString error }, Cmd.none )


messageEncoder : Model -> Json.Encode.Value
messageEncoder model =
    Json.Encode.object
        [ ( "content", Json.Encode.string model.inputContent )
        , ( "date", Json.Encode.string model.inputDate )
        , ( "time", Json.Encode.string model.inputTime )
        , ( "uid"
          , case model.userData of
                Just userData ->
                    Json.Encode.string userData.uid

                Maybe.Nothing ->
                    Json.Encode.null
          )
        ]


messageToError : String -> ErrorData
messageToError message =
    { code = Maybe.Nothing, credential = Maybe.Nothing, message = Just message }


errorPrinter : ErrorData -> String
errorPrinter errorData =
    Maybe.withDefault "" errorData.code ++ " " ++ Maybe.withDefault "" errorData.credential ++ " " ++ Maybe.withDefault "" errorData.message


userDataDecoder : Json.Decode.Decoder UserData
userDataDecoder =
    Json.Decode.succeed UserData
        |> Json.Decode.Pipeline.required "token" Json.Decode.string
        |> Json.Decode.Pipeline.required "email" Json.Decode.string
        |> Json.Decode.Pipeline.required "uid" Json.Decode.string


logInErrorDecoder : Json.Decode.Decoder ErrorData
logInErrorDecoder =
    Json.Decode.succeed ErrorData
        |> Json.Decode.Pipeline.required "code" (Json.Decode.nullable Json.Decode.string)
        |> Json.Decode.Pipeline.required "message" (Json.Decode.nullable Json.Decode.string)
        |> Json.Decode.Pipeline.required "credential" (Json.Decode.nullable Json.Decode.string)


messageDecoder : Json.Decode.Decoder MessageContent
messageDecoder =
    Json.Decode.succeed MessageContent
        |> Json.Decode.Pipeline.required "content" Json.Decode.string
        |> Json.Decode.Pipeline.required "date" Json.Decode.string
        |> Json.Decode.Pipeline.required "time" Json.Decode.string


messageListDecoder : Json.Decode.Decoder (List MessageContent)
messageListDecoder =
    Json.Decode.list messageDecoder


---- VIEW ----


view : Model -> Html Msg
view model =
    div []
        [
         case model.userData of
            Just data ->
                button [ onClick LogOut ] [ text "Logout from Google" ]

            Maybe.Nothing ->
                button [ onClick LogIn ] [ text "Login with Google" ]
        , h2 []
            [ text <|
                case model.userData of
                    Just data ->
                        data.email

                    Maybe.Nothing ->
                        ""
            ]
        , case model.userData of
            Just data ->
                div []
                    [ input [ placeholder "Message to save", value model.inputContent, onInput InputChanged ] []
                    , input [ placeholder "Date", value model.inputDate, onInput DateChanged ] []
                    , input [ placeholder "Time", value model.inputTime, onInput TimeChanged ] []
                    , button [ onClick SaveMessage ] [ text "Save new message" ]
                    ]

            Maybe.Nothing ->
                div [] []
        , div [ style "display" "flex", style "justify-content" "center"]
            [ h3 []
                [ text "Previous messages"
                , table [ class "table is-striped" ]
                    [ thead []
                        [ tr []
                            [ th [] [ text "Content" ]
                            , th [] [ text "Date" ]
                            , th [] [ text "Time" ]
                            ]
                        ]
                    , tbody []
                        <| List.map
                            (\m -> tr [] [ td [] [ text m.content ], td [] [ text m.date ], td [] [ text m.time ] ])
                            model.messages
                    ]
                ]
            ]
        , h2 [] [ text <| errorPrinter model.error ]
        ]




---- PROGRAM ----


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ signInInfo (Json.Decode.decodeValue userDataDecoder >> LoggedInData)
        , signInError (Json.Decode.decodeValue logInErrorDecoder >> LoggedInError)
        , receiveMessages (Json.Decode.decodeValue messageListDecoder >> MessagesReceived)
        ]


main : Program () Model Msg
main =
    Browser.element
        { view = view
        , init = \_ -> init
        , update = update
        , subscriptions = subscriptions
        }
