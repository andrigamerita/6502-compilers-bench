.export benched_routine
.import zipped_data
.importzp tmpfield1, tmpfield2, tmpfield3, tmpfield4, tmpfield5, tmpfield6, tmpfield7

.segment "CODE"
; Copy a compressed nametable to mem buffer
;  tmpfield1 - zipped data address (low)
;  tmpfield2 - zipped data address (high)
;  tmpfield3 - unzipped data offset (low)
;  tmpfield4 - unzipped data offset (high)
;  tmpfield5 - unzipped data count
;
; Overwrites all registers, tmpfield1-7
get_unzipped_bytes:
.scope
	compressed_nametable = tmpfield1
	offset = tmpfield3
	count = tmpfield5
	current = tmpfield6
	zero_counter = tmpfield7 ; WARNING - used temporarily, read the code before using it
	unzip_buffer = $0580

	lda #0
	sta current

	ldx #0
	ldy #0
	skip_bytes:
	.scope
		; Decrement offset, stop on zero
		.scope
			lda offset
			bne no_carry
				carry:
					lda offset+1
					beq end_skip_bytes
					dec offset+1
				no_carry:
					dec offset
		.endscope
		loop_without_dec:

		; Take action,
		;  - output a zero if in compressed series
		;  - output the byte on normal bytes
		;  - init compressed series on opcode
		cpx #0
		bne compressed_zero
		lda (compressed_nametable), y
		beq opcode

			normal_byte:
				;NEXT_BYTE
				.scope
					iny
					bne end_inc_vector
					inc compressed_nametable+1
					end_inc_vector:
				.endscope
				jmp skip_bytes

			opcode:
				; X = number of uncompressed zeros to output
				;NEXT_BYTE
				.scope
					iny
					bne end_inc_vector
					inc compressed_nametable+1
					end_inc_vector:
				.endscope
				lda (compressed_nametable), y
				tax
				;NEXT_BYTE
				.scope
					iny
					bne end_inc_vector
					inc compressed_nametable+1
					end_inc_vector:
				.endscope

				; Skip iterating on useless zeros
				;  note - This code checks only offset's msb to know if offset > X.
				;         It could be finer grained to gain some cycles (to be tested on need)
				.scope
					lda offset+1
					beq done

						skip_all:
							stx zero_counter
							ldx #0

							sec
							lda offset
							sbc zero_counter
							sta offset
							lda offset+1
							sbc #0
							sta offset+1

					done:
				.endscope

				jmp loop_without_dec ; force the loop, we did not get uncompressed byte

			compressed_zero:
				dex
				jmp skip_bytes

		end_skip_bytes:
	.endscope

	get_bytes:
	.scope
		; Take action,
		;  - output a zero if in compressed series
		;  - output the byte on normal bytes
		;  - init compressed series on opcode
		cpx #0
		bne compressed_zero
		lda (compressed_nametable), y
		beq opcode

			normal_byte:
				;GOT_BYTE
				.scope
					ldx current
					sta unzip_buffer, x
					inc current
				.endscope
				;NEXT_BYTE
				.scope
					iny
					bne end_inc_vector
					inc compressed_nametable+1
					end_inc_vector:
				.endscope
				ldx #0
				jmp loop_get_bytes

			opcode:
				;NEXT_BYTE
				.scope
					iny
					bne end_inc_vector
					inc compressed_nametable+1
					end_inc_vector:
				.endscope
				lda (compressed_nametable), y
				tax
				;NEXT_BYTE
				.scope
					iny
					bne end_inc_vector
					inc compressed_nametable+1
					end_inc_vector:
				.endscope
				jmp get_bytes  ; force the loop, we did not get uncompressed byte

			compressed_zero:
				stx zero_counter
				lda #0
				;GOT_BYTE
				.scope
					ldx current
					sta unzip_buffer, x
					inc current
				.endscope
				ldx zero_counter
				dex
				;jmp loop_get_bytes ; useless fallthrough

		; Check loop count
		loop_get_bytes:
		dec count
		force_loop_get_bytes:
		bne get_bytes
	.endscope

	end:
	rts
.endscope

benched_routine:
.scope
	lda #<zipped_data
	sta tmpfield1
	lda #>zipped_data
	sta tmpfield2

	lda #$a8
	sta tmpfield3
	lda #$03
	sta tmpfield4

	lda #16
	sta tmpfield5

	jmp get_unzipped_bytes
.endscope
