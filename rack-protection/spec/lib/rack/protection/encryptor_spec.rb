# frozen_string_literal: true

RSpec.describe Rack::Protection::Encryptor do
  let(:secret) do
    OpenSSL::Cipher.new(Rack::Protection::Encryptor::CIPHER).random_key
  end

  it 'encrypted message contains ciphertext iv and auth_tag' do
    msg = Rack::Protection::Encryptor.encrypt_message('hello world', secret)

    ctxt, iv, auth_tag = msg.split(Rack::Protection::Encryptor::DELIMITER, 3)

    expect(ctxt).not_to be_empty
    expect(iv).not_to be_empty
    expect(auth_tag).not_to be_empty
  end

  it 'encrypted message is decryptable' do
    cmsg = Rack::Protection::Encryptor.encrypt_message('hello world', secret)
    pmsg = Rack::Protection::Encryptor.decrypt_message(cmsg, secret)

    expect(pmsg).to eql('hello world')
  end

  it 'encryptor and decryptor handles overly long keys' do
    new_secret = "#{secret}abcdef123456"

    # These methos should truncate the long key (so OpenSSL raise exceptions)
    cmsg = Rack::Protection::Encryptor.encrypt_message('hello world', new_secret)
    pmsg = Rack::Protection::Encryptor.decrypt_message(cmsg, new_secret)

    expect(pmsg).to eq('hello world')
  end

  it 'decrypt returns nil for junk messages' do
    pmsg = Rack::Protection::Encryptor.decrypt_message('aaa--bbb-ccc', secret)

    expect(pmsg).to be_nil
  end

  it 'decrypt returns nil for tampered messages' do
    cmsg = Rack::Protection::Encryptor.encrypt_message('hello world', secret)

    csplit = cmsg.split(Rack::Protection::Encryptor::DELIMITER, 3)
    csplit[2] = csplit.last.reverse

    tampered_msg = csplit.join(Rack::Protection::Encryptor::DELIMITER)
    pmsg = Rack::Protection::Encryptor.decrypt_message(tampered_msg, secret)

    expect(pmsg).to be_nil
  end
end
